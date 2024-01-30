unit NtUtils.DbgHelp;

{
  This module provides functions for working with debug symbols via the
  DbgHelp library.
}

// TODO: figure out why it doesn't work under WoW64

interface

uses
  Ntapi.DbgHelp, NtUtils, NtUtils.Ldr, DelphiApi.Reflection;

type
  ISymbolContext = interface (IAutoReleasable)
    function GetProcess: IHandle;
    property Process: IHandle read GetProcess;
  end;

  ISymbolModule = interface (IAutoReleasable)
    function GetContext: ISymbolContext;
    function GetBaseAddress: Pointer;
    property Context: ISymbolContext read GetContext;
    property BaseAddress: Pointer read GetBaseAddress;
  end;

  TSymbolEntry = record
    [Hex] RVA: UInt64;
    [Bytes] Size: Cardinal;
    Flags: TSymbolFlags;
    Tag: TSymTagEnum;
    Name: String;
  end;

  TBestMatchSymbol = record
    Module: TModuleEntry;
    Symbol: TSymbolEntry;
    [Hex] Offset: UInt64;
    function ToString: String;
  end;

// Initialize symbols for a process
function SymxInitialize(
  out SymContext: ISymbolContext;
  const hxProcess: IHandle;
  Invade: Boolean
): TNtxStatus;

// Load symbols for a module
function SymxLoadModule(
  out Module: ISymbolModule;
  const Context: ISymbolContext;
  [opt] const ImageName: String;
  [opt] hFile: THandle;
  [in] Base: Pointer;
  Size: NativeUInt;
  LoadExternalSymbols: Boolean = True
): TNtxStatus;

// Enumerate symbols in a module
function SymxEnumSymbols(
  out Symbols: TArray<TSymbolEntry>;
  const Module: ISymbolModule;
  const Mask: String = '*'
): TNtxStatus;

// Enumerate symbols in a file
function SymxEnumSymbolsFile(
  out Symbols: TArray<TSymbolEntry>;
  const ImageName: String;
  LoadExternalSymbols: Boolean = True
): TNtxStatus;

// Enumerate symbols in a file caching the results
function SymxCacheEnumSymbolsFile(
  const FileName: String;
  out Symbols: TArray<TSymbolEntry>
): TNtxStatus;

// Find the nearest symbol to the corresponding RVA in the module
function SymxFindBestMatchModule(
  const Module: TModuleEntry;
  const Symbols: TArray<TSymbolEntry>;
  const RVA: UInt64
): TBestMatchSymbol;

// Find the nearest symbol within the nearest module
function SymxFindBestMatch(
  const Modules: TArray<TModuleEntry>;
  [in] Address: Pointer
): TBestMatchSymbol;

implementation

uses
  Ntapi.WinNt, Ntapi.ntstatus, DelphiUtils.AutoObjects,
  NtUtils.Processes, NtUtils.SysUtils, DelphiUtils.Arrays;

{$BOOLEVAL OFF}
{$IFOPT R+}{$DEFINE R+}{$ENDIF}
{$IFOPT Q+}{$DEFINE Q+}{$ENDIF}

type
  TAutoSymbolContext = class (TCustomAutoReleasable, ISymbolContext)
    FProcess: IHandle;
    function GetProcess: IHandle;
    constructor Capture(const hxProcess: IHandle);
    procedure Release; override;
  end;

  TAutoSymbolModule = class (TCustomAutoReleasable, ISymbolModule)
    FContext: ISymbolContext;
    FBaseAddress: Pointer;
    function GetContext: ISymbolContext;
    function GetBaseAddress: Pointer;
    constructor Capture(const Context: ISymbolContext; Address: Pointer);
    procedure Release; override;
  end;

{ TAutoSymbolContext }

constructor TAutoSymbolContext.Capture;
begin
  inherited Create;
  FProcess := hxProcess;
end;

procedure TAutoSymbolContext.Release;
begin
  if Assigned(FProcess) then
    SymCleanup(FProcess.Handle);

  FProcess := nil;
  inherited;
end;

function TAutoSymbolContext.GetProcess;
begin
  Result := FProcess;
end;

{ TAutoSymbolModule }

constructor TAutoSymbolModule.Capture;
begin
  inherited Create;
  FContext := Context;
  FBaseAddress := Address;
end;

procedure TAutoSymbolModule.Release;
begin
  if Assigned(FContext) and Assigned(FContext.Process) and
    Assigned(FBaseAddress) then
    SymUnloadModule64(FContext.Process.Handle, FBaseAddress);

  FContext := nil;
  FBaseAddress := nil;
  inherited;
end;

function TAutoSymbolModule.GetBaseAddress;
begin
  Result := FBaseAddress;
end;

function TAutoSymbolModule.GetContext;
begin
  Result := FContext;
end;

{ TBestMatchSymbol }

function TBestMatchSymbol.ToString;
begin
  Result := Module.BaseDllName;

  if Symbol.Name <> '' then
    Result := Result + '!' + Symbol.Name;

  if Offset <> 0 then
  begin
    if Result <> '' then
      Result := Result + '+';

    Result := Result + RtlxUInt64ToStr(Offset, nsHexadecimal);
  end;
end;

{ Functions }

function SymxInitialize;
begin
  Result.Location := 'SymInitializeW';
  Result.Win32Result := SymInitializeW(hxProcess.Handle, nil, Invade);

  if Result.IsSuccess then
    SymContext := TAutoSymbolContext.Capture(hxProcess);
end;

function SymxLoadModule;
var
  BaseAddress: Pointer;
  Flags: TSymLoadFlags;
begin
  // Should we search for DBG or PDB files that the module references?
  if LoadExternalSymbols then
    Flags := 0
  else
    Flags := SLMFLAG_NO_SYMBOLS;

  Result.Location := 'SymLoadModuleExW';
  BaseAddress := SymLoadModuleExW(Context.Process.Handle, hFile,
    PWideChar(ImageName), nil, Base, Size, nil, Flags);
  Result.Win32Result := Assigned(BaseAddress);

  if Result.IsSuccess then
    Module := TAutoSymbolModule.Capture(Context, BaseAddress);
end;

function EnumCallback(
  const SymInfo: TSymbolInfoW;
  SymbolSize: Cardinal;
  var UserContext
): LongBool; stdcall;
var
  Collection: TArray<TSymbolEntry> absolute UserContext;
begin
  SetLength(Collection, Length(Collection) + 1);

  with Collection[High(Collection)] do
  begin
    RVA := UIntPtr(SymInfo.Address) - UIntPtr(SymInfo.ModBase);
    Size := SymInfo.Size;
    Flags := SymInfo.Flags;
    Tag := SymInfo.Tag;
    Name := RtlxCaptureString(SymInfo.Name, SymInfo.NameLen);
  end;

  Result := True;
end;

function SymxEnumSymbols;
begin
  Symbols := nil;

  Result.Location := 'SymEnumSymbolsW';
  Result.Win32Result := SymEnumSymbolsW(Module.Context.Process.Handle,
    Module.BaseAddress, PWideChar(Mask), EnumCallback, Symbols);

  if not Result.IsSuccess then
    Symbols := nil;
end;

function SymxEnumSymbolsFile;
const
  DEFAULT_BASE = Pointer($1);
var
  hxProcess: IHandle;
  Context: ISymbolContext;
  Module: ISymbolModule;
begin
  // Create a unique handle to the current process to avoid collisions
  Result := NtxOpenCurrentProcess(hxProcess, MAXIMUM_ALLOWED);

  if not Result.IsSuccess then
    Exit;

  Result := SymxInitialize(Context, hxProcess, False);

  if not Result.IsSuccess then
    Exit;

  // When loading PDB or DBG files, we cannot supply null pointer as a base
  // address. However, since we are interested only in RVAs, we can use
  // any other value of our choice.

  Result := SymxLoadModule(Module, Context, ImageName, 0, DEFAULT_BASE, 0,
    LoadExternalSymbols);

  if not Result.IsSuccess then
    Exit;

  Result := SymxEnumSymbols(Symbols, Module);
end;

var
  // Symbol cache
  SymxNamesCache: TArray<String>;
  SymxSymbolCache: TArray<TArray<TSymbolEntry>>;

function SymxCacheEnumSymbolsFile;
var
  Index: Integer;
begin
  // Check if we have the module cached
  Index := TArray.BinarySearchEx<String>(SymxNamesCache,
    function (const Entry: String): Integer
    begin
      Result := RtlxCompareStrings(Entry, FileName);
    end
  );

  // Cache hit
  if Index >= 0 then
  begin
    Symbols := SymxSymbolCache[Index];
    Result.Status := STATUS_ALREADY_COMPLETE;
    Exit;
  end;

  // Cache miss, load symbols
  Result := SymxEnumSymbolsFile(Symbols, FileName);

  if not Result.IsSuccess then
    Exit;

  // Save into the cache, preserving its order
  Index := -(Index + 1);
  Insert(FileName, SymxNamesCache, Index);
  Insert(Symbols, SymxSymbolCache, Index);
end;

function SymxFindBestMatchModule;
var
  i: Integer;
  Distance: UInt64;
  BestMatch: Integer;
begin
  BestMatch := -1;
  Distance := UInt64(-1);

  for i := 0 to High(Symbols) do
    if (Symbols[i].RVA <> 0) and (Symbols[i].RVA <= RVA) and
      (RVA - Symbols[i].RVA < Distance) then
    begin
      Distance := RVA - Symbols[i].RVA;
      BestMatch := i;
    end;

  if BestMatch < 0 then
  begin
    // Make a pseudo-symbol for the whole module
    Result.Symbol.RVA := 0;
    Result.Symbol.Size := Module.SizeOfImage;
    Result.Symbol.Flags := SYMFLAG_VIRTUAL;
    Result.Symbol.Tag := TSymTagEnum.SymTagExe;
    Result.Symbol.Name := '';
  end
  else
    Result.Symbol := Symbols[BestMatch];

  Result.Module := Module;
  Result.Offset := RVA - Result.Symbol.RVA;
end;

function SymxFindBestMatch;
var
  i: Integer;
  Symbols: TArray<TSymbolEntry>;
begin
  // Find the module containing the address

  for i := 0 to High(Modules) do
    if Modules[i].IsInRange(Address) then
    begin
      // Try loading symbols for this module
      if not SymxCacheEnumSymbolsFile(Modules[i].FullDllName,
        Symbols).IsSuccess then
        Symbols := nil;

      // Find the best matching symbol
      Result := SymxFindBestMatchModule(Modules[i], Symbols, UIntPtr(Address) -
        UIntPtr(Modules[i].DllBase));

      Exit;
    end;

  // No module found, make a pseudo-symbol for the address
  Result := Default(TBestMatchSymbol);
  Result.Symbol.Flags := SYMFLAG_VIRTUAL;
  Result.Offset := UIntPtr(Address);
end;

end.
