unit NtUtils.Files.Folders;

interface

uses
  Ntapi.ntioapi, NtUtils, DelphiApi.Reflection;

type
  TFolderContentInfo = record
    [Aggregate] Times: TFileTimes;
    [Bytes] EndOfFile: UInt64;
    [Bytes] AllocationSize: UInt64;
    FileAttributes: TFileAttributes;
    Name: String;
  end;

  // Note: ContinuePropagation is defaulted to True and matters only for folders
  TFileCallback = function(const FileInfo: TFolderContentInfo; Root: IHandle;
    RootName: String; var ContinuePropagation: Boolean): TNtxStatus;

  TFileTraverseOptions = set of (ftInvokeOnFiles, ftInvokeOnFolders,
    ftIgnoreCallbackFailures, ftIgnoreTraverseFailures);

// Enumerate content of a folder
function NtxEnumerateFolder(hFolder: THandle; out Files:
  TArray<TFolderContentInfo>; Pattern: String = ''): TNtxStatus;

// Recursively traverse a folder and its sub-folders
function NtxTraverseFolder(hxFolder: IHandle; Path: String; Callback:
  TFileCallback; Options: TFileTraverseOptions = [ftInvokeOnFiles,
  ftInvokeOnFolders]; MaxDepth: Integer = 32): TNtxStatus;

implementation

uses
  Ntapi.ntdef, Ntapi.ntstatus, NtUtils.Files, NtUtils.Objects;

function NtxEnumerateFolder(hFolder: THandle; out Files:
  TArray<TFolderContentInfo>; Pattern: String): TNtxStatus;
const
  BUFFER_SIZE = $F00;
var
  IoStatusBlock: TIoStatusBlock;
  xMemory: IMemory;
  Buffer: PFileDirectoryInformation;
  FirstScan: Boolean;
begin
  FirstScan := True;

  Result.Location := 'NtQueryDirectoryFile';
  Result.LastCall.Expects<TIoDirectoryAccessMask>(FILE_LIST_DIRECTORY);
  Result.LastCall.AttachInfoClass(FileDirectoryInformation);

  repeat
    // Retrieve a portion of files
    IMemory(xMemory) := TAutoMemory.Allocate(BUFFER_SIZE);
    repeat
      Result.Status := NtQueryDirectoryFile(hFolder, 0, nil, nil,
        IoStatusBlock, xMemory.Data, xMemory.Size, FileDirectoryInformation,
        False, TNtUnicodeString.From(Pattern).RefOrNull, FirstScan);

      // Since IoStatusBlock is on our stack, we must wait for completion
      if Result.Status = STATUS_PENDING then
      begin
        Result := NtxWaitForSingleObject(hFolder);

        if Result.IsSuccess then
          Result.Status := IoStatusBlock.Status;
      end;
    until not NtxExpandBufferEx(Result, IMemory(xMemory), xMemory.Size shl 1, nil);

    // Nothing left to do
    if Result.Status = STATUS_NO_MORE_FILES then
    begin
      Result.Status := STATUS_SUCCESS;
      Break;
    end
    else if not Result.IsSuccess then
      Break;

    // Collect all the files we recieved
    Buffer := xMemory.Data;
    repeat
      SetLength(Files, Succ(Length(Files)));

      with Files[High(Files)] do
      begin
        Times := Buffer.Times;
        EndOfFile := Buffer.EndOfFile;
        AllocationSize := Buffer.AllocationSize;
        FileAttributes := Buffer.FileAttributes;
        SetString(Name, Buffer.FileName, Buffer.FileNameLength div
          SizeOf(WideChar));
      end;

      if Buffer.NextEntryOffset = 0 then
        Break;

      Buffer := Pointer(UIntPtr(Buffer) + Buffer.NextEntryOffset);
    until False;

    FirstScan := False;
  until False;
end;

function NtxTraverseFolder(hxFolder: IHandle; Path: String; Callback:
  TFileCallback; Options: TFileTraverseOptions; MaxDepth: Integer): TNtxStatus;
var
  Files: TArray<TFolderContentInfo>;
  hxSubFolder: IHandle;
  IsFolder, ContinuePropagation: Boolean;
  i: Integer;
begin
  // Open the folder if necessary. Can happen only on the top of the hierarchy.
  if not Assigned(hxFolder) then
  begin
    Result := NtxOpenFile(hxFolder, FILE_LIST_DIRECTORY, Path);

    if not Result.IsSuccess then
      Exit;
  end;

  // Get listing of files and folders inside
  Result := NtxEnumerateFolder(hxFolder.Handle, Files);

  if not Result.IsSuccess then
  begin
    // Allow skipping this folder if we cannot enumerate it
    if not (ftIgnoreTraverseFailures in Options) then
      Result.Status := STATUS_MORE_ENTRIES;

    Exit;
  end;

  for i := 0 to High(Files) do
  begin
    // Skip pseudo-directories
    if (Files[i].Name = '.') or (Files[i].Name = '..')  then
      Continue;

    ContinuePropagation := True;
    IsFolder := LongBool(Files[i].FileAttributes and
      FILE_ATTRIBUTE_DIRECTORY);

    // Invoke the callback
    if (IsFolder and (ftInvokeOnFolders in Options)) or
      (not IsFolder and (ftInvokeOnFiles in Options)) then
    begin
      Result := Callback(Files[i], hxFolder, Path, ContinuePropagation);

      // Handle failures
      if ftIgnoreCallbackFailures in Options then
        Result.Status := STATUS_SUCCESS
      else if not Result.IsSuccess then
        Exit;
    end;

    // Traverse sub-folders
    if IsFolder and ContinuePropagation and (MaxDepth > 0) then
    begin
      Result := NtxOpenFile(hxSubFolder, FILE_LIST_DIRECTORY, Files[i].Name,
        hxFolder.Handle);

      if not Result.IsSuccess then
      begin
        // Allow skipping folders we cannot access
        if ftIgnoreTraverseFailures in Options then
          Continue;

        Exit;
      end;

      // Call recursively
      Result := NtxTraverseFolder(hxSubFolder, Path + '\' + Files[i].Name,
        Callback, Options, MaxDepth - 1);

      if not Result.IsSuccess then
        Exit;
    end;
  end;
end;

end.