unit NtUtils;

{
  Base definitions for the NtUtils library.
}

interface

uses
  Winapi.WinNt, Ntapi.ntdef, Ntapi.ntseapi, Winapi.WinError,
  DelphiApi.Reflection, DelphiUtils.AutoObjects;

const
  BUFFER_LIMIT = 1024 * 1024 * 1024; // 1 GiB

  // From ntapi.ntstatus
  STATUS_SUCCESS = NTSTATUS(0);

var
  // Controls whether TNtxStatus should capture stack traces on failure.
  // When enabled, you should also configure generation of debug symbols via
  // Project -> Options -> Building -> Delphi Compiler -> Linking -> Map File.
  // This switch controls creation of .map files which you can later convert
  // into .dbg using the map2dbg tool. See the link for more details:
  // https://stackoverflow.com/questions/9422703
  CaptureStackTraces: Boolean = False;

type
  // A few macros/aliases for checking bit flags and better expressing intent.
  // Note: do not use with 64-bit or native integers!
  BitTest = LongBool;
  HasAny = LongBool;

  // Forward the types for automatic lifetime management
  IAutoReleasable = DelphiUtils.AutoObjects.IAutoReleasable;
  IAutoObject = DelphiUtils.AutoObjects.IAutoObject;
  TMemory = DelphiUtils.AutoObjects.TMemory;
  IMemory = DelphiUtils.AutoObjects.IMemory;
  IHandle = DelphiUtils.AutoObjects.IHandle;
  Auto = DelphiUtils.AutoObjects.Auto;

  // Define commonly used IMemory aliases
  IEnvironment = IMemory<PEnvironment>;
  ISecDesc = IMemory<PSecurityDescriptor>;
  INtUnicodeString = IMemory<PNtUnicodeString>;
  IWideChar = IMemory<PWideChar>;
  IContext = IMemory<PContext>;
  IAcl = IMemory<PAcl>;
  ISid = IMemory<PSid>;

  // Forward SAL annotations
  InAttribute = DelphiApi.Reflection.InAttribute;
  OutAttribute = DelphiApi.Reflection.OutAttribute;
  OptAttribute = DelphiApi.Reflection.OptAttribute;
  AccessAttribute = DelphiApi.Reflection.AccessAttribute;

  // A Delphi wrapper for a commonly used OBJECT_ATTRIBUTES type that allows
  // building it with a simplified (fluent) syntaxt.
  IObjectAttributes = interface
    // Fluent builder
    function UseRoot(const RootDirectory: IHandle): IObjectAttributes;
    function UseName(const ObjectName: String): IObjectAttributes;
    function UseAttributes(const Attributes: TObjectAttributesFlags): IObjectAttributes;
    function UseSecurity(const SecurityDescriptor: ISecDesc): IObjectAttributes;
    function UseImpersonation(const Level: TSecurityImpersonationLevel = SecurityImpersonation): IObjectAttributes;
    function UseEffectiveOnly(const Enabled: Boolean = True): IObjectAttributes;
    function UseDesiredAccess(const AccessMask: TAccessMask): IObjectAttributes;

    // Accessors
    function Root: IHandle;
    function Name: String;
    function Attributes: TObjectAttributesFlags;
    function Security: ISecDesc;
    function Impersonation: TSecurityImpersonationLevel;
    function EffectiveOnly: Boolean;
    function DesiredAccess: TAccessMask;

    // Integration
    function ToNative: PObjectAttributes;
    function Duplicate: IObjectAttributes;
  end;

  TGroup = record
    Sid: ISid;
    Attributes: TGroupAttributes;
  end;

  { Error Handling }

  TLastCallType = (lcOtherCall, lcOpenCall, lcQuerySetCall);
  TInfoClassOperation = (icUnknown, icQuery, icSet, icControl, icPerform);

  TExpectedAccess = record
    AccessMask: TAccessMask;
    AccessMaskType: Pointer;
  end;

  TLastCallInfo = record
    Location: String;
    StackTrace: TArray<Pointer>;
    ExpectedPrivilege: TSeWellKnownPrivilege;
    ExpectedAccess: TArray<TExpectedAccess>;
    procedure CaptureStackTrace;
    procedure OpensForAccess<T>(Mask: T);
    procedure Expects<T>(AccessMask: T);
    procedure UsesInfoClass<T>(
      InfoClassEnum: T;
      Operation: TInfoClassOperation
    );
  case CallType: TLastCallType of
    lcOpenCall: (
      AccessMask: TAccessMask;
      AccessMaskType: Pointer
    );

    lcQuerySetCall: (
      InfoClassOperation: TInfoClassOperation;
      InfoClass: Cardinal;
      InfoClassType: Pointer
    );
  end;

  // An enhanced NTSTATUS that stores additional information about the last
  // operation and the location of failure.
  TNtxStatus = record
  private
    FStatus: NTSTATUS;

    function GetWin32Error: TWin32Error;
    function GetHResult: HResult;
    function GetLocation: String;

    procedure FromWin32Error(const Value: TWin32Error);
    procedure FromLastWin32Error(const RetValue: Boolean);
    procedure FromHResult(const Value: HResult);
    procedure FromHResultAllowFalse(const Value: HResult);
    procedure FromStatus(const Value: NTSTATUS);

    procedure SetLocation(const Value: String); inline;
  public
    LastCall: TLastCallInfo;

    // Validation
    function IsSuccess: Boolean; inline;
    function IsFailOrTimeout: Boolean;
    function IsWin32: Boolean;
    function IsHResult: Boolean;

    // Integration
    property Status: NTSTATUS read FStatus write FromStatus;
    property Win32Error: TWin32Error read GetWin32Error write FromWin32Error;
    property HResult: HResult read GetHResult write FromHResult;
    property HResultAllowFalse: HResult write FromHResultAllowFalse;
    property Win32Result: Boolean write FromLastWin32Error;

    property Location: String read GetLocation write SetLocation;
    function Matches(Status: NTSTATUS; Location: String): Boolean; inline;

    // Support for inline assignment and iterators
    function Save(var Target: TNtxStatus): Boolean;
  end;

  { Buffer Expansion }

  TBufferGrowthMethod = function (
    const Memory: IMemory;
    Required: NativeUInt
  ): NativeUInt;

// Slightly adjust required size with + 12% to mitigate fluctuations
function Grow12Percent(
  const Memory: IMemory;
  Required: NativeUInt
): NativeUInt;

function NtxExpandBufferEx(
  var Status: TNtxStatus;
  var Memory: IMemory;
  Required: NativeUInt;
  GrowthMetod: TBufferGrowthMethod
): Boolean;

{ Object Attributes }

// Use an existing or create a new instance of an object attribute builder.
function AttributeBuilder(
  [opt] const ObjAttributes: IObjectAttributes = nil
): IObjectAttributes;

// Make a copy of an object attribute builder or create a new instance
function AttributeBuilderCopy(
  [opt] const ObjAttributes: IObjectAttributes = nil
): IObjectAttributes;

// Get an NT object attribute pointer from an interfaced object attributes
function AttributesRefOrNil(
  [opt] const ObjAttributes: IObjectAttributes
): PObjectAttributes;

// Let the caller override a default access mask via Object Attributes when
// creating kernel objects.
function AccessMaskOverride(
  DefaultAccess: TAccessMask;
  [opt] const ObjAttributes: IObjectAttributes
): TAccessMask;

{ Helper functions }

function RefStrOrNil(const S: String): PWideChar;
function RefNtStrOrNil(const [ref] S: TNtUnicodeString): PNtUnicodeString;
function HandleOrDefault(const hxObject: IHandle; Default: THandle = 0): THandle;

implementation

uses
  Ntapi.ntrtl, Ntapi.ntstatus, NtUtils.ObjAttr, NtUtils.Errors;

{ Object Attributes }

function AttributeBuilder;
begin
  if Assigned(ObjAttributes) then
    Result := ObjAttributes
  else
    Result := NewAttributeBuilder;
end;

function AttributeBuilderCopy;
begin
  if Assigned(ObjAttributes) then
    Result := ObjAttributes.Duplicate
  else
    Result := NewAttributeBuilder;
end;

function AttributesRefOrNil;
begin
  if Assigned(ObjAttributes) then
    Result := ObjAttributes.ToNative
  else
    Result := nil;
end;

function AccessMaskOverride;
begin
  if Assigned(ObjAttributes) and (ObjAttributes.DesiredAccess <> 0) then
    Result := ObjAttributes.DesiredAccess
  else
    Result := DefaultAccess;
end;

{ TLastCallInfo }

procedure TLastCallInfo.CaptureStackTrace;
const
  MAX_DEPTH = 32;
begin
  SetLength(StackTrace, MAX_DEPTH);
  SetLength(StackTrace, RtlCaptureStackBackTrace(2, MAX_DEPTH, StackTrace, nil))
end;

procedure TLastCallInfo.Expects<T>;
var
  Mask: TAccessMask absolute AccessMask;
begin
  if Mask = 0 then
    Exit;

  // Add new access mask
  SetLength(ExpectedAccess, Length(ExpectedAccess) + 1);
  ExpectedAccess[High(ExpectedAccess)].AccessMask := Mask;
  ExpectedAccess[High(ExpectedAccess)].AccessMaskType := TypeInfo(T);
end;

procedure TLastCallInfo.OpensForAccess<T>;
var
  AsAccessMask: TAccessMask absolute Mask;
begin
  CallType := lcOpenCall;
  AccessMask := AsAccessMask;
  AccessMaskType := TypeInfo(T);
end;

procedure TLastCallInfo.UsesInfoClass<T>;
var
  AsByte: Byte absolute InfoClassEnum;
  AsWord: Word absolute InfoClassEnum;
  AsCardinal: Cardinal absolute InfoClassEnum;
begin
  CallType := lcQuerySetCall;
  InfoClassOperation := Operation;
  InfoClassType := TypeInfo(T);

  case SizeOf(T) of
    SizeOf(Byte):     InfoClass := AsByte;
    SizeOf(Word):     InfoClass := AsWord;
    SizeOf(Cardinal): InfoClass := AsCardinal;
  end;
end;

{ TNtxStatus }

procedure TNtxStatus.FromHResult;
begin
  // S_FALSE is a controversial value that is successful, but indicates a
  // failure. Its precise meaning depends on the context, so whenever we expect
  // it as a result we should adjust the logic correspondingly. By default,
  // consider it unsuccessful. For the opposite behavior, use HResultAllowFalse.

  if Value = S_FALSE then
    Status := STATUS_UNSUCCESSFUL
  else
    Status := Value.ToNtStatus;
end;

procedure TNtxStatus.FromHResultAllowFalse(const Value: HResult);
begin
  // Note: if you want S_FALSE to be unsuccessful, see comments in FromHResult.

  Status := Value.ToNtStatus;
end;

procedure TNtxStatus.FromLastWin32Error;
begin
  if RetValue then
    Status := STATUS_SUCCESS
  else
    Status := RtlxGetLastNtStatus(True);
end;

procedure TNtxStatus.FromStatus;
begin
  FStatus := Value;
  RtlSetLastWin32ErrorAndNtStatusFromNtStatus(Value);

  if not IsSuccess and CaptureStackTraces then
    LastCall.CaptureStackTrace;
end;

procedure TNtxStatus.FromWin32Error;
begin
  Status := Win32Error.ToNtStatus;
end;

function TNtxStatus.GetHResult;
begin
  Result := Status.ToHResult;
end;

function TNtxStatus.GetLocation;
begin
  Result := LastCall.Location;
end;

function TNtxStatus.GetWin32Error;
begin
  Result := Status.ToWin32Error;
end;

function TNtxStatus.IsFailOrTimeout;
begin
  Result := not IsSuccess or (Status = STATUS_TIMEOUT);

  // Make timeouts unsuccessful
  if Status = STATUS_TIMEOUT then
    Status := STATUS_WAIT_TIMEOUT;
end;

function TNtxStatus.IsHResult;
begin
  Result := Status.IsHResult;
end;

function TNtxStatus.IsSuccess;
begin
  Result := Integer(Status) >= 0; // inlined NT_SUCCESS / Succeeded
end;

function TNtxStatus.IsWin32;
begin
  Result := Status.IsWin32Error;
end;

function TNtxStatus.Matches;
begin
  Result := (Self.Status = Status) and (Self.Location = Location);
end;

function TNtxStatus.Save;
begin
  Result := IsSuccess;
  Target := Self;

  // Stop iterating without forwarding the error code
  if Status = STATUS_NO_MORE_ENTRIES then
    Target.Status := STATUS_SUCCESS;
end;

procedure TNtxStatus.SetLocation;
begin
  LastCall := Default(TLastCallInfo);
  LastCall.Location := Value;
end;

{ Functions }

function Grow12Percent;
begin
  Result := Required;
  Inc(Result, Result shr 3);
end;

function NtxExpandBufferEx;
begin
  // True means continue; False means break from the loop
  Result := False;

  case Status.Status of
    STATUS_INFO_LENGTH_MISMATCH, STATUS_BUFFER_TOO_SMALL,
    STATUS_BUFFER_OVERFLOW:
    begin
      // Grow the buffer with provided callback
      if Assigned(GrowthMetod) then
        Required := GrowthMetod(Memory, Required);

      // The buffer should always grow, not shrink
      if (Assigned(Memory) and (Required <= Memory.Size)) or (Required = 0) then
        Exit(False);

      // Check for the limitation
      if Required > BUFFER_LIMIT then
      begin
        Status.Location := 'NtxExpandBufferEx';
        Status.Status := STATUS_IMPLEMENTATION_LIMIT;
        Exit(False);
      end;

      Memory := Auto.AllocateDynamic(Required);
      Result := True;
    end;
  end;
end;

{ Helper functions }

function RefStrOrNil;
begin
  if S <> '' then
    Result := PWideChar(S)
  else
    Result := nil;
end;

function RefNtStrOrNil;
begin
  if S.Length <> 0 then
    Result := @S
  else
    Result := nil;
end;

function HandleOrDefault;
begin
  if Assigned(hxObject) then
    Result := hxObject.Handle
  else
    Result := Default;
end;

end.
