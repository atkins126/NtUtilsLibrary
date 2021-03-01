unit NtUtils.Registry;

interface

uses
  Winapi.WinNt, Ntapi.ntregapi, NtUtils, NtUtils.Objects,
  DelphiUtils.AutoObject, DelphiUtils.Async;

type
  TRegValueType = Ntapi.ntregapi.TRegValueType;

  TKeyBasicInfo = record
    LastWriteTime: TLargeInteger;
    TitleIndex: Cardinal;
    Name: String;
  end;

  TRegValueEntry = record
    ValueType: TRegValueType;
    ValueName: String;
  end;

  TSubKeyEntry = record
    ProcessId: TProcessId;
    KeyName: String;
  end;

{ Keys }

// Open a key
function NtxOpenKey(out hxKey: IHandle; Name: String;
  DesiredAccess: TAccessMask; OpenOptions: TRegOpenOptions = 0;
  ObjectAttributes: IObjectAttributes = nil): TNtxStatus;

// Create a key
function NtxCreateKey(out hxKey: IHandle; Name: String; DesiredAccess:
  TAccessMask; CreateOptions: TRegOpenOptions = 0; ObjectAttributes:
  IObjectAttributes = nil; Disposition: PRegDisposition = nil): TNtxStatus;

// Delete a key
function NtxDeleteKey(hKey: THandle): TNtxStatus;

// Rename a key
function NtxRenameKey(hKey: THandle; NewName: String): TNtxStatus;

// Enumerate keys using an information class
function NtxEnumerateKey(hKey: THandle; Index: Integer; InfoClass:
  TKeyInformationClass; out xMemory: IMemory; InitialBuffer: Cardinal = 0;
  GrowthMethod: TBufferGrowthMethod = nil): TNtxStatus;

// Enumerate sub-keys
function NtxEnumerateSubKeys(hKey: THandle; out SubKeys: TArray<String>)
  : TNtxStatus;

// Query variable-length key information
function NtxQueryInformationKey(hKey: THandle; InfoClass: TKeyInformationClass;
  out xMemory: IMemory; InitialBuffer: Cardinal = 0; GrowthMethod:
  TBufferGrowthMethod = nil): TNtxStatus;

// Query key basic information
function NtxQueryBasicKey(hKey: THandle; out Info: TKeyBasicInfo): TNtxStatus;

type
  NtxKey = class
    // Query fixed-size key information
    class function Query<T>(hKey: THandle; InfoClass: TKeyInformationClass;
      out Buffer: T): TNtxStatus; static;

    // Set fixed-size key information
    class function SetInfo<T>(hKey: THandle; InfoClass: TKeySetInformationClass;
      const Buffer: T): TNtxStatus; static;
  end;

{ Symbolic Links }

// Create a symbolic link key
function NtxCreateSymlinkKey(Source: String; Target: String; Options:
  Cardinal = 0; ObjectAttributes: IObjectAttributes = nil): TNtxStatus;

// Delete a symbolic link key
function NtxDeleteSymlinkKey(Name: String; Root: IHandle = nil; Options:
  Cardinal = 0): TNtxStatus;

{ Values }

// Enumerate values using an information class
function NtxEnumerateValueKey(hKey: THandle; Index: Integer; InfoClass:
  TKeyValueInformationClass; out xMemory: IMemory; InitialBuffer: Cardinal = 0;
  GrowthMethod: TBufferGrowthMethod = nil): TNtxStatus;

// Enumerate values of a key
function NtxEnumerateValuesKey(hKey: THandle;
  out ValueNames: TArray<TRegValueEntry>): TNtxStatus;

// Query variable-length value information
function NtxQueryValueKey(hKey: THandle; ValueName: String; InfoClass:
  TKeyValueInformationClass; out xMemory: IMemory; InitialBuffer: Cardinal = 0;
  GrowthMethod: TBufferGrowthMethod = nil): TNtxStatus;

// Query raw value data of a key
function NtxQueryPartialValueKey(hKey: THandle; ValueName: String;
  ExpectedSize: Cardinal; out xMemory: IMemory<PKeyValuePartialInfromation>):
  TNtxStatus;

// Query value of a DWORD type
function NtxQueryDwordValueKey(hKey: THandle; ValueName: String;
  out Value: Cardinal): TNtxStatus;

// Query value of a string type
function NtxQueryStringValueKey(hKey: THandle; ValueName: String;
  out Value: String): TNtxStatus;

// Query value of a multi-string type
function NtxQueryMultiStringValueKey(hKey: THandle; ValueName: String;
  out Value: TArray<String>): TNtxStatus;

// Set value
function NtxSetValueKey(hKey: THandle; ValueName: String;
  ValueType: TRegValueType; Data: Pointer; DataSize: Cardinal): TNtxStatus;

// Set a DWORD value
function NtxSetDwordValueKey(hKey: THandle; ValueName: String; Value: Cardinal)
  : TNtxStatus;

// Set a string value
function NtxSetStringValueKey(hKey: THandle; ValueName: String; Value: String;
  ValueType: TRegValueType = REG_SZ): TNtxStatus;

// Set a multi-string value
function NtxSetMultiStringValueKey(hKey: THandle; ValueName: String;
  Value: TArray<String>): TNtxStatus;

// Delete a value
function NtxDeleteValueKey(hKey: THandle; ValueName: String): TNtxStatus;

{ Other }

// Mount a hive file to the registry
function NtxLoadKeyEx(out hxKey: IHandle; FileName: String; KeyPath: String;
  Flags: Cardinal = 0; TrustClassKey: THandle = 0; FileObjAttr:
  IObjectAttributes = nil; KeyObjAttr: IObjectAttributes = nil): TNtxStatus;

// Unmount a hive file from the registry
function NtxUnloadKey(KeyName: String; Force: Boolean = False; ObjectAttributes:
  IObjectAttributes = nil): TNtxStatus;

// Enumerate opened subkeys from a part of the registry
function NtxEnumerateOpenedSubkeys(out SubKeys: TArray<TSubKeyEntry>;
  KeyName: String; ObjectAttributes: IObjectAttributes = nil): TNtxStatus;

// Subsribe for registry changes notifications
function NtxNotifyChangeKey(hKey: THandle; Flags: TRegNotifyFlags;
  WatchTree: Boolean; Callback: TAnonymousApcCallback): TNtxStatus;

implementation

uses
  Ntapi.ntdef, Ntapi.ntstatus, Ntapi.ntseapi, Ntapi.ntioapi, DelphiUtils.Arrays;

{ Keys }

function NtxOpenKey(out hxKey: IHandle; Name: String; DesiredAccess:
  TAccessMask; OpenOptions: TRegOpenOptions; ObjectAttributes:
  IObjectAttributes): TNtxStatus;
var
  hKey: THandle;
begin
  Result.Location := 'NtOpenKeyEx';
  Result.LastCall.AttachAccess<TRegKeyAccessMask>(DesiredAccess);

  Result.Status := NtOpenKeyEx(hKey, DesiredAccess,
    AttributeBuilder(ObjectAttributes).UseName(Name).ToNative, OpenOptions);

  if Result.IsSuccess then
    hxKey := TAutoHandle.Capture(hKey);
end;

function NtxCreateKey(out hxKey: IHandle; Name: String; DesiredAccess:
  TAccessMask; CreateOptions: TRegOpenOptions; ObjectAttributes:
  IObjectAttributes; Disposition: PRegDisposition): TNtxStatus;
var
  hKey: THandle;
begin
  Result.Location := 'NtCreateKey';
  Result.LastCall.AttachAccess<TRegKeyAccessMask>(DesiredAccess);

  Result.Status := NtCreateKey(hKey, DesiredAccess,
    AttributeBuilder(ObjectAttributes).UseName(Name).ToNative, 0, nil,
    CreateOptions, Disposition);

  if Result.IsSuccess then
    hxKey := TAutoHandle.Capture(hKey);
end;

function NtxDeleteKey(hKey: THandle): TNtxStatus;
begin
  Result.Location := 'NtDeleteKey';
  Result.LastCall.Expects<TRegKeyAccessMask>(_DELETE);

  Result.Status := NtDeleteKey(hKey);
end;

function NtxRenameKey(hKey: THandle; NewName: String): TNtxStatus;
begin
  Result.Location := 'NtRenameKey';
  Result.LastCall.Expects<TRegKeyAccessMask>(READ_CONTROL or KEY_SET_VALUE or
    KEY_CREATE_SUB_KEY);

  // Or READ_CONTROL | KEY_NOTIFY | KEY_ENUMERATE_SUB_KEYS | KEY_QUERY_VALUE
  // in case of enabled virtualization

  Result.Status := NtRenameKey(hKey, TNtUnicodeString.From(NewName));
end;

function NtxEnumerateKey(hKey: THandle; Index: Integer; InfoClass:
  TKeyInformationClass; out xMemory: IMemory; InitialBuffer: Cardinal;
  GrowthMethod: TBufferGrowthMethod): TNtxStatus;
var
  Required: Cardinal;
begin
  Result.Location := 'NtEnumerateKey';
  Result.LastCall.AttachInfoClass(InfoClass);
  Result.LastCall.Expects<TRegKeyAccessMask>(KEY_ENUMERATE_SUB_KEYS);

  xMemory := TAutoMemory.Allocate(InitialBuffer);
  repeat
    Required := 0;
    Result.Status := NtEnumerateKey(hKey, Index, InfoClass, xMemory.Data,
      xMemory.Size, Required);
  until not NtxExpandBufferEx(Result, xMemory, Required, GrowthMethod);
end;

function NtxEnumerateSubKeys(hKey: THandle; out SubKeys: TArray<String>)
  : TNtxStatus;
var
  xMemory: IMemory<PKeyBasicInformation>;
  Index: Integer;
begin
  SetLength(SubKeys, 0);

  Index := 0;
  repeat
    // Query sub-key name
    Result := NtxEnumerateKey(hKey, Index, KeyBasicInformation,
      IMemory(xMemory));

    if Result.IsSuccess then
    begin
      SetLength(SubKeys, Length(SubKeys) + 1);
      SetString(SubKeys[High(SubKeys)], PWideChar(@xMemory.Data.Name),
        xMemory.Data.NameLength div SizeOf(WideChar));
    end;

    Inc(Index);
  until not Result.IsSuccess;

  if Result.Status = STATUS_NO_MORE_ENTRIES then
    Result.Status := STATUS_SUCCESS;
end;

function NtxQueryInformationKey(hKey: THandle; InfoClass: TKeyInformationClass;
  out xMemory: IMemory; InitialBuffer: Cardinal; GrowthMethod:
  TBufferGrowthMethod): TNtxStatus;
var
  Required: Cardinal;
begin
  Result.Location := 'NtQueryKey';
  Result.LastCall.AttachInfoClass(InfoClass);

  if not (InfoClass in [KeyNameInformation, KeyHandleTagsInformation]) then
    Result.LastCall.Expects<TRegKeyAccessMask>(KEY_QUERY_VALUE);

  xMemory := TAutoMemory.Allocate(InitialBuffer);
  repeat
    Required := 0;
    Result.Status := NtQueryKey(hKey, InfoClass, xMemory.Data, xMemory.Size,
      Required);
  until not NtxExpandBufferEx(Result, xMemory, Required, GrowthMethod);
end;

function NtxQueryBasicKey(hKey: THandle; out Info: TKeyBasicInfo): TNtxStatus;
var
  xMemory: IMemory<PKeyBasicInformation>;
begin
  Result := NtxQueryInformationKey(hKey, KeyBasicInformation, IMemory(xMemory));

  if Result.IsSuccess then
  begin
    Info.LastWriteTime := xMemory.Data.LastWriteTime;
    Info.TitleIndex := xMemory.Data.TitleIndex;
    SetString(Info.Name, PWideChar(@xMemory.Data.Name),
      xMemory.Data.NameLength div SizeOf(WideChar));
  end;
end;

class function NtxKey.Query<T>(hKey: THandle; InfoClass: TKeyInformationClass;
  out Buffer: T): TNtxStatus;
var
  Returned: Cardinal;
begin
  Result.Location := 'NtQueryKey';
  Result.LastCall.AttachInfoClass(InfoClass);

  if not (InfoClass in [KeyNameInformation, KeyHandleTagsInformation]) then
    Result.LastCall.Expects<TRegKeyAccessMask>(KEY_QUERY_VALUE);

  Result.Status := NtQueryKey(hKey, InfoClass, @Buffer, SizeOf(Buffer),
    Returned);
end;

class function NtxKey.SetInfo<T>(hKey: THandle;
  InfoClass: TKeySetInformationClass; const Buffer: T): TNtxStatus;
begin
  Result.Location := 'NtSetInformationKey';
  Result.LastCall.AttachInfoClass(InfoClass);

  if InfoClass <> KeySetHandleTagsInformation then
    Result.LastCall.Expects<TRegKeyAccessMask>(KEY_SET_VALUE);

  // Or READ_CONTROL | KEY_NOTIFY | KEY_ENUMERATE_SUB_KEYS | KEY_QUERY_VALUE
  // in case of enabled virtualization

  Result.Status := NtSetInformationKey(hKey, InfoClass, @Buffer,
    SizeOf(Buffer));
end;

{ Symbolic Links }

function NtxCreateSymlinkKey(Source: String; Target: String;
  Options: Cardinal; ObjectAttributes: IObjectAttributes): TNtxStatus;
var
  hxKey: IHandle;
begin
  // Create a key
  Result := NtxCreateKey(hxKey, Source, KEY_SET_VALUE or KEY_CREATE_LINK,
    Options or REG_OPTION_CREATE_LINK, ObjectAttributes);

  if Result.IsSuccess then
  begin
    // Set its link target
    Result := NtxSetStringValueKey(hxKey.Handle, REG_SYMLINK_VALUE_NAME, Target,
      REG_LINK);

    // Undo key creation on failure
    if not Result.IsSuccess then
      NtxDeleteKey(hxKey.Handle);
  end;
end;

function NtxDeleteSymlinkKey(Name: String; Root: IHandle; Options: Cardinal)
  : TNtxStatus;
var
  hxKey: IHandle;
begin
  Result := NtxOpenKey(hxKey, Name, _DELETE, Options, AttributeBuilder
    .UseAttributes(OBJ_OPENLINK).UseRoot(Root));

  if Result.IsSuccess then
    Result := NtxDeleteKey(hxKey.Handle);
end;

{ Values }

function NtxEnumerateValueKey(hKey: THandle; Index: Integer; InfoClass:
  TKeyValueInformationClass; out xMemory: IMemory; InitialBuffer: Cardinal;
  GrowthMethod: TBufferGrowthMethod): TNtxStatus;
var
  Required: Cardinal;
begin
  Result.Location := 'NtEnumerateValueKey';
  Result.LastCall.AttachInfoClass(InfoClass);
  Result.LastCall.Expects<TRegKeyAccessMask>(KEY_QUERY_VALUE);

  xMemory := TAutoMemory.Allocate(InitialBuffer);
  repeat
    Required := 0;
    Result.Status := NtEnumerateValueKey(hKey, Index, InfoClass, xMemory.Data,
      xMemory.Size, Required);
  until not NtxExpandBufferEx(Result, xMemory, Required, GrowthMethod);
end;

function NtxEnumerateValuesKey(hKey: THandle;
  out ValueNames: TArray<TRegValueEntry>): TNtxStatus;
var
  Index: Integer;
  xMemory: IMemory<PKeyValueBasicInformation>;
begin
  SetLength(ValueNames, 0);

  Index := 0;
  repeat
    Result := NtxEnumerateValueKey(hKey, Index, KeyValueBasicInformation,
      IMemory(xMemory));

    if Result.IsSuccess then
    begin
      SetLength(ValueNames, Length(ValueNames) + 1);
      ValueNames[High(ValueNames)].ValueType := xMemory.Data.ValueType;
      SetString(ValueNames[High(ValueNames)].ValueName, PWideChar(
        @xMemory.Data.Name), xMemory.Data.NameLength div SizeOf(WideChar));
    end;

    Inc(Index);
  until not Result.IsSuccess;

  if Result.Status = STATUS_NO_MORE_ENTRIES then
    Result.Status := STATUS_SUCCESS;
end;

function NtxQueryValueKey(hKey: THandle; ValueName: String; InfoClass:
  TKeyValueInformationClass; out xMemory: IMemory; InitialBuffer: Cardinal;
  GrowthMethod: TBufferGrowthMethod): TNtxStatus;
var
  NameStr: TNtUnicodeString;
  Required: Cardinal;
begin
  Result.Location := 'NtQueryValueKey';
  Result.LastCall.AttachInfoClass(InfoClass);
  Result.LastCall.Expects<TRegKeyAccessMask>(KEY_QUERY_VALUE);

  NameStr := TNtUnicodeString.From(ValueName);

  xMemory := TAutoMemory.Allocate(InitialBuffer);
  repeat
    Required := 0;
    Result.Status := NtQueryValueKey(hKey, NameStr, InfoClass, xMemory.Data,
      xMemory.Size, Required);
  until not NtxExpandBufferEx(Result, xMemory, Required, GrowthMethod);
end;

function GrowPartial(Memory: IMemory; Required: NativeUInt): NativeUInt;
begin
  Result := SizeOf(TKeyValuePartialInfromation) +
    PKeyValuePartialInfromation(Memory.Data).DataLength;

  if Result < Required then
    Result := Required;
end;

function NtxQueryPartialValueKey(hKey: THandle; ValueName: String;
  ExpectedSize: Cardinal; out xMemory: IMemory<PKeyValuePartialInfromation>):
  TNtxStatus;
begin
  Result := NtxQueryValueKey(hKey, ValueName, KeyValuePartialInformation,
    IMemory(xMemory), SizeOf(TKeyValuePartialInfromation) - SizeOf(Byte) +
    ExpectedSize, GrowPartial);
end;

function NtxQueryDwordValueKey(hKey: THandle; ValueName: String;
  out Value: Cardinal): TNtxStatus;
var
  xMemory: IMemory<PKeyValuePartialInfromation>;
begin
  Result := NtxQueryPartialValueKey(hKey, ValueName, SizeOf(Cardinal),
    xMemory);

  if Result.IsSuccess then
    case xMemory.Data.ValueType of
      REG_DWORD:
        Value := PCardinal(@xMemory.Data.Data)^;
    else
      Result.Location := 'NtxQueryDwordValueKey';
      Result.Status := STATUS_OBJECT_TYPE_MISMATCH;
    end;
end;

function NtxQueryStringValueKey(hKey: THandle; ValueName: String;
  out Value: String): TNtxStatus;
var
  xMemory: IMemory<PKeyValuePartialInfromation>;
begin
  Result := NtxQueryPartialValueKey(hKey, ValueName, SizeOf(WideChar),
    xMemory);

  if Result.IsSuccess then
    case xMemory.Data.ValueType of
      REG_SZ, REG_EXPAND_SZ, REG_LINK, REG_MULTI_SZ:
        SetString(Value, PWideChar(@xMemory.Data.Data),
          xMemory.Data.DataLength div SizeOf(WideChar) - 1);
    else
      Result.Location := 'NtxQueryStringValueKey';
      Result.Status := STATUS_OBJECT_TYPE_MISMATCH;
    end;
end;

function NtxQueryMultiStringValueKey(hKey: THandle; ValueName: String;
  out Value: TArray<String>): TNtxStatus;
var
  xMemory: IMemory<PKeyValuePartialInfromation>;
begin
  Result := NtxQueryPartialValueKey(hKey, ValueName, SizeOf(WideChar),
    xMemory);

  if Result.IsSuccess then
    case xMemory.Data.ValueType of
      REG_SZ, REG_EXPAND_SZ, REG_LINK:
        begin
          SetLength(Value, 1);
          SetString(Value[0], PWideChar(@xMemory.Data.Data),
            xMemory.Data.DataLength div SizeOf(WideChar) - 1);
        end;

      REG_MULTI_SZ:
        Value := ParseMultiSz(PWideChar(@xMemory.Data.Data),
          xMemory.Data.DataLength div SizeOf(WideChar));
    else
      Result.Location := 'NtxQueryMultiStringValueKey';
      Result.Status := STATUS_OBJECT_TYPE_MISMATCH;
    end;
end;

function NtxSetValueKey(hKey: THandle; ValueName: String;
  ValueType: TRegValueType; Data: Pointer; DataSize: Cardinal): TNtxStatus;
begin
  Result.Location := 'NtSetValueKey';
  Result.LastCall.Expects<TRegKeyAccessMask>(KEY_SET_VALUE);

  Result.Status := NtSetValueKey(hKey, TNtUnicodeString.From(ValueName), 0,
    ValueType, Data, DataSize);
end;

function NtxSetDwordValueKey(hKey: THandle; ValueName: String; Value: Cardinal)
  : TNtxStatus;
begin
  Result := NtxSetValueKey(hKey, ValueName, REG_DWORD, @Value, SizeOf(Value));
end;

function NtxSetStringValueKey(hKey: THandle; ValueName: String; Value: String;
  ValueType: TRegValueType): TNtxStatus;
begin
  Result := NtxSetValueKey(hKey, ValueName, ValueType, PWideChar(Value),
    Length(Value) * SizeOf(WideChar));
end;

function NtxSetMultiStringValueKey(hKey: THandle; ValueName: String;
  Value: TArray<String>): TNtxStatus;
var
  xMemory: IMemory;
  pCurrentPosition: PWideChar;
  BufferSize: Cardinal;
  i: Integer;
begin
  // Calculate required memory
  BufferSize := SizeOf(WideChar); // Include additional #0 at the end
  for i := 0 to High(Value) do
    Inc(BufferSize, Succ(Length(Value[i])) * SizeOf(WideChar));

  xMemory := TAutoMemory.Allocate(BufferSize);

  pCurrentPosition := xMemory.Data;
  for i := 0 to High(Value) do
  begin
    // Copy each string
    Move(PWideChar(Value[i])^, pCurrentPosition^,
      Length(Value[i]) * SizeOf(WideChar));

    // Add zero termination
    Inc(pCurrentPosition, Length(Value[i]) + 1);
  end;

  Result := NtxSetValueKey(hKey, ValueName, REG_MULTI_SZ, xMemory.Data,
    xMemory.Size);
end;

function NtxDeleteValueKey(hKey: THandle; ValueName: String): TNtxStatus;
begin
  Result.Location := 'NtDeleteValueKey';
  Result.LastCall.Expects<TRegKeyAccessMask>(KEY_SET_VALUE);

  // Or READ_CONTROL | KEY_NOTIFY | KEY_ENUMERATE_SUB_KEYS | KEY_QUERY_VALUE
  // in case of enabled virtualization

  Result.Status := NtDeleteValueKey(hKey, TNtUnicodeString.From(ValueName));
end;

function NtxLoadKeyEx(out hxKey: IHandle; FileName: String; KeyPath: String;
  Flags: Cardinal; TrustClassKey: THandle; FileObjAttr, KeyObjAttr:
  IObjectAttributes): TNtxStatus;
var
  hKey: THandle;
begin
  // Make sure we always get the handle
  Flags := Flags or REG_LOAD_HIVE_OPEN_HANDLE;

  Result.Location := 'NtLoadKeyEx';
  Result.LastCall.ExpectedPrivilege := SE_RESTORE_PRIVILEGE;

  Result.Status := NtLoadKeyEx(AttributeBuilder(KeyObjAttr).UseName(KeyPath)
    .ToNative, AttributeBuilder(FileObjAttr).UseName(FileName).ToNative,
    Flags, TrustClassKey, 0, KEY_ALL_ACCESS, hKey, nil);

  if Result.IsSuccess then
    hxKey := TAutoHandle.Capture(hKey);
end;

function NtxUnloadKey(KeyName: String; Force: Boolean; ObjectAttributes:
  IObjectAttributes): TNtxStatus;
var
  Flags: Cardinal;
begin
  if Force then
    Flags := REG_FORCE_UNLOAD
  else
    Flags := 0;

  Result.Location := 'NtUnloadKey2';
  Result.LastCall.ExpectedPrivilege := SE_RESTORE_PRIVILEGE;
  Result.Status := NtUnloadKey2(AttributeBuilder(ObjectAttributes)
    .UseName(KeyName).ToNative, Flags);
end;

function NtxEnumerateOpenedSubkeys(out SubKeys: TArray<TSubKeyEntry>;
  KeyName: String; ObjectAttributes: IObjectAttributes): TNtxStatus;
var
  pObjAttr: PObjectAttributes;
  xMemory: IMemory<PKeyOpenSubkeysInformation>;
  RequiredSize: Cardinal;
  i: Integer;
begin
  pObjAttr := AttributeBuilder(ObjectAttributes).UseName(KeyName).ToNative;

  Result.Location := 'NtQueryOpenSubKeysEx';
  Result.LastCall.ExpectedPrivilege := SE_RESTORE_PRIVILEGE;

  IMemory(xMemory) := TAutoMemory.Allocate($1000);
  repeat
    Result.Status := NtQueryOpenSubKeysEx(pObjAttr, xMemory.Size, xMemory.Data,
      RequiredSize);
  until not NtxExpandBufferEx(Result, IMemory(xMemory), RequiredSize, nil);

  if not Result.IsSuccess then
    Exit;

  SetLength(SubKeys, xMemory.Data.Count);

  for i := 0 to High(SubKeys) do
    with SubKeys[i] do
    begin
      ProcessId := xMemory.Data.KeyArray{$R-}[i]{$R+}.ProcessId;
      KeyName := xMemory.Data.KeyArray{$R-}[i]{$R+}.KeyName.ToString;
    end;
end;

function NtxNotifyChangeKey(hKey: THandle; Flags: TRegNotifyFlags;
  WatchTree: Boolean; Callback: TAnonymousApcCallback): TNtxStatus;
var
  AsyncContext: IAnonymousIoApcContext;
  IoStatusBlock: TIoStatusBlock;
  IoStatusBlockRef: PIoStatusBlock;
begin
  if Assigned(Callback) then
  begin
      AsyncContext := TAnonymousIoApcContext.Create(Callback);

      // Prolong the lifetime of the captured variables and the I/O status block
      IoStatusBlockRef := AsyncContext.IoStatusBlock;
      AsyncContext._AddRef;
  end
  else
  begin
    // Use local block on the stack
    AsyncContext := nil;
    IoStatusBlockRef := @IoStatusBlock;
  end;

  Result.Location := 'NtNotifyChangeKey';
  Result.LastCall.Expects<TRegKeyAccessMask>(KEY_NOTIFY);

  Result.Status := NtNotifyChangeKey(hKey, 0, ApcCallbackForwarder,
    Pointer(AsyncContext), IoStatusBlockRef, Flags, WatchTree, nil, 0,
    Assigned(Callback));

  // Undo referencing on failure
  if Assigned(AsyncContext) and not Result.IsSuccess then
    AsyncContext._Release;
end;

end.
