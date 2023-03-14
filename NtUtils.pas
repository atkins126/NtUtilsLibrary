unit NtUtils;

{
  Base definitions for the NtUtils library.
}

interface

uses
  Ntapi.WinNt, Ntapi.ntdef, Ntapi.ntseapi, Ntapi.WinError,
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
  IAutoPointer = DelphiUtils.AutoObjects.IAutoPointer;
  TMemory = DelphiUtils.AutoObjects.TMemory;
  IMemory = DelphiUtils.AutoObjects.IMemory;
  IHandle = DelphiUtils.AutoObjects.IHandle;
  Auto = DelphiUtils.AutoObjects.Auto;

  // Define commonly used IMemory aliases
  IEnvironment = IMemory<PEnvironment>;
  ISecurityDescriptor = IMemory<PSecurityDescriptor>;
  INtUnicodeString = IMemory<PNtUnicodeString>;
  IWideChar = IMemory<PWideChar>;
  IContext = IMemory<PContext>;
  IAcl = IMemory<PAcl>;
  ISid = IMemory<PSid>;

  // Forward SAL annotations
  InAttribute = DelphiApi.Reflection.InAttribute;
  OutAttribute = DelphiApi.Reflection.OutAttribute;
  OptAttribute = DelphiApi.Reflection.OptAttribute;
  MayReturnNilAttribute = DelphiApi.Reflection.MayReturnNilAttribute;
  AccessAttribute = DelphiApi.Reflection.AccessAttribute;

  // A Delphi wrapper for a commonly used OBJECT_ATTRIBUTES type that allows
  // building it with a simplified (fluent) syntaxt.
  IObjectAttributes = interface
    // Fluent builder
    function UseRoot(const RootDirectory: IHandle): IObjectAttributes;
    function UseName(const ObjectName: String): IObjectAttributes;
    function UseAttributes(const Attributes: TObjectAttributesFlags): IObjectAttributes;
    function UseSecurity(const SecurityDescriptor: ISecurityDescriptor): IObjectAttributes;
    function UseImpersonation(const Level: TSecurityImpersonationLevel = SecurityImpersonation): IObjectAttributes;
    function UseEffectiveOnly(const Enabled: Boolean = True): IObjectAttributes;
    function UseDesiredAccess(const AccessMask: TAccessMask): IObjectAttributes;

    // Accessor functions
    function GetRoot: IHandle;
    function GetName: String;
    function GetAttributes: TObjectAttributesFlags;
    function GetSecurity: ISecurityDescriptor;
    function GetImpersonation: TSecurityImpersonationLevel;
    function GetEffectiveOnly: Boolean;
    function GetDesiredAccess: TAccessMask;

    // Accessors
    property Root: IHandle read GetRoot;
    property Name: String read GetName;
    property Attributes: TObjectAttributesFlags read GetAttributes;
    property Security: ISecurityDescriptor read GetSecurity;
    property Impersonation: TSecurityImpersonationLevel read GetImpersonation;
    property EffectiveOnly: Boolean read GetEffectiveOnly;
    property DesiredAccess: TAccessMask read GetDesiredAccess;

    // Integration
    function ToNative: PObjectAttributes;
  end;

  TGroup = record
    Sid: ISid;
    Attributes: TGroupAttributes;
    class function From(
      const Sid: ISid;
      Attributes: TGroupAttributes
    ): TGroup; static;
  end;

  { Error Handling }

  [NamingStyle(nsCamelCase, 'lc')]
  TLastCallType = (lcOtherCall, lcOpenCall, lcQuerySetCall);

  [NamingStyle(nsCamelCase, 'ic')]
  TInfoClassOperation = (icUnknown, icQuery, icSet, icRead, icWrite, icControl,
    icPerform);

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
    procedure FromWin32ErrorOrSuccess(const Value: TWin32Error);
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

    // Conversion
    property Status: NTSTATUS read FStatus write FromStatus;
    property Win32Error: TWin32Error read GetWin32Error write FromWin32Error;
    property Win32ErrorOrSuccess: TWin32Error write FromWin32ErrorOrSuccess;
    property HResult: HResult read GetHResult write FromHResult;
    property HResultAllowFalse: HResult write FromHResultAllowFalse;
    property Win32Result: Boolean write FromLastWin32Error;

    property Location: String read GetLocation write SetLocation;
    function Matches(Status: NTSTATUS; Location: String): Boolean; inline;

    // Support for inline assignment and iterators
    function Save(var Target: TNtxStatus): Boolean;
  end;

{ Stack tracing }

// Get the address of the next instruction after the call
function RtlxNextInstruction: Pointer;

// Capture a stack trace of the current thread
function RtlxCaptureStackTrace(
  FramesToSkip: Integer = 0
): TArray<Pointer>;

{ Buffer Expansion }

type
  TBufferGrowthMethod = function (
    const Memory: IMemory;
    Required: NativeUInt
  ): NativeUInt;

// Slightly adjust required size with + 12% to mitigate fluctuations
function Grow12Percent(
  const Memory: IMemory;
  Required: NativeUInt
): NativeUInt;

// Re-allocate the buffer according to the required size
function NtxExpandBufferEx(
  var Status: TNtxStatus;
  var Memory: IMemory;
  Required: NativeUInt;
  [opt] GrowthMetod: TBufferGrowthMethod
): Boolean;

{ Object Attributes }

// Make an instance of an object attribute builder
function AttributeBuilder(
  [opt] const Template: IObjectAttributes = nil
): IObjectAttributes;

// Get an NT object attribute pointer from an interfaced object attributes
function AttributesRefOrNil(
  [opt] const ObjAttributes: IObjectAttributes
): PObjectAttributes;

// Let the caller override the default access mask via Object Attributes when
// creating kernel objects.
function AccessMaskOverride(
  DefaultAccess: TAccessMask;
  [opt] const ObjAttributes: IObjectAttributes
): TAccessMask;

{ Helper functions }

// Count the number of bytes required to store a string without terminating zero
[Result: NumberOfBytes]
function StringSizeNoZero(const S: String): NativeUInt;

// Count the number of bytes required to store a string with terminating zero
[Result: NumberOfBytes]
function StringSizeZero(const S: String): NativeUInt;

// Write a string into a buffer
procedure MarshalString(
  [in] const Source: String;
  [out, WritesTo] Buffer: Pointer
);

// Write an NT unicode string into a buffer
procedure MarshalUnicodeString(
  [in] const Source: String;
  [out] out Target: TNtUnicodeString;
  [out, WritesTo] Buffer: Pointer
);

function RefStrOrNil(const S: String): PWideChar;
function HandleOrDefault(const hxObject: IHandle; Default: THandle = 0): THandle;

{ Shared delay free functions }

// Free a string buffer using RtlFreeUnicodeString after use
function RtlxDelayFreeUnicodeString(
  [in] Buffer: PNtUnicodeString
): IAutoReleasable;

// Free a SID buffer using RtlFreeSid after use
function RtlxDelayFreeSid(
  [in] Buffer: PSid
): IAutoReleasable;

// Free a buffer using LocalFree after use
function AdvxDelayLocalFree(
  [in] Buffer: Pointer
): IAutoReleasable;

implementation

uses
  Ntapi.ntrtl, Ntapi.ntstatus, Ntapi.WinBase, NtUtils.Errors;

{$BOOLEVAL OFF}
{$IFOPT R+}{$DEFINE R+}{$ENDIF}
{$IFOPT Q+}{$DEFINE Q+}{$ENDIF}

{ Object Attributes }

type
  TNtxObjectAttributes = class (TInterfacedObject, IObjectAttributes)
  private
    FObjAttr: TObjectAttributes;
    FQoS: TSecurityQualityOfService;
    FRoot: IHandle;
    FName: String;
    FNameStr: TNtUnicodeString;
    FSecurity: ISecurityDescriptor;
    FAccessMask: TAccessMask;
    function SetRoot(const Value: IHandle): TNtxObjectAttributes;
    function SetName(const Value: String): TNtxObjectAttributes;
    function SetAttributes(const Value: TObjectAttributesFlags): TNtxObjectAttributes;
    function SetSecurity(const Value: ISecurityDescriptor): TNtxObjectAttributes;
    function SetImpersonation(const Value: TSecurityImpersonationLevel): TNtxObjectAttributes;
    function SetEffectiveOnly(const Value: Boolean): TNtxObjectAttributes;
    function SetDesiredAccess(const Value: TAccessMask): TNtxObjectAttributes;
    function Duplicate: TNtxObjectAttributes;
  public
    constructor Create;
    function GetRoot: IHandle;
    function GetName: String;
    function GetAttributes: TObjectAttributesFlags;
    function GetSecurity: ISecurityDescriptor;
    function GetImpersonation: TSecurityImpersonationLevel;
    function GetEffectiveOnly: Boolean;
    function GetDesiredAccess: TAccessMask;
    function ToNative: PObjectAttributes;
    function UseRoot(const Value: IHandle): IObjectAttributes;
    function UseName(const Value: String): IObjectAttributes;
    function UseAttributes(const Value: TObjectAttributesFlags): IObjectAttributes;
    function UseSecurity(const Value: ISecurityDescriptor): IObjectAttributes;
    function UseImpersonation(const Value: TSecurityImpersonationLevel): IObjectAttributes;
    function UseEffectiveOnly(const Value: Boolean): IObjectAttributes;
    function UseDesiredAccess(const Value: TAccessMask): IObjectAttributes;
  end;

constructor TNtxObjectAttributes.Create;
begin
  inherited;
  FObjAttr.Length := SizeOf(TObjectAttributes);
  FObjAttr.SecurityQualityOfService := @FQoS;
  FQoS.Length := SizeOf(TSecurityQualityOfService);
  FQoS.ImpersonationLevel := SecurityImpersonation;
end;

function TNtxObjectAttributes.Duplicate;
begin
  Result := TNtxObjectAttributes.Create
    .SetRoot(GetRoot)
    .SetName(GetName)
    .SetAttributes(GetAttributes)
    .SetSecurity(GetSecurity)
    .SetImpersonation(GetImpersonation)
    .SetEffectiveOnly(GetEffectiveOnly);
end;

function TNtxObjectAttributes.GetAttributes;
begin
  Result := FObjAttr.Attributes;
end;

function TNtxObjectAttributes.GetDesiredAccess;
begin
  Result := FAccessMask;
end;

function TNtxObjectAttributes.GetEffectiveOnly;
begin
  Result := FQoS.EffectiveOnly;
end;

function TNtxObjectAttributes.GetImpersonation;
begin
  Result := FQoS.ImpersonationLevel;
end;

function TNtxObjectAttributes.GetName;
begin
  Result := FName;
end;

function TNtxObjectAttributes.GetRoot;
begin
  Result := FRoot;
end;

function TNtxObjectAttributes.GetSecurity;
begin
  Result := FSecurity;
end;

function TNtxObjectAttributes.SetAttributes;
begin
  FObjAttr.Attributes := Value;
  Result := Self;
end;

function TNtxObjectAttributes.SetDesiredAccess;
begin
  FAccessMask := Value;
  Result := Self;
end;

function TNtxObjectAttributes.SetEffectiveOnly;
begin
  FQoS.EffectiveOnly := Value;
  Result := Self;
end;

function TNtxObjectAttributes.SetImpersonation;
begin
  FQoS.ImpersonationLevel := Value;
  Result := Self;
end;

function TNtxObjectAttributes.SetName;
begin
  FName := Value;
  FNameStr := TNtUnicodeString.From(FName);
  FObjAttr.ObjectName := FNameStr.RefOrNil;
  Result := Self;
end;

function TNtxObjectAttributes.SetRoot;
begin
  FRoot := Value;
  FObjAttr.RootDirectory := HandleOrDefault(FRoot);
  Result := Self;
end;

function TNtxObjectAttributes.SetSecurity;
begin
  FSecurity := Value;
  FObjAttr.SecurityDescriptor := Auto.RefOrNil<PSecurityDescriptor>(FSecurity);
  Result := Self;
end;

function TNtxObjectAttributes.ToNative;
begin
  Result := @FObjAttr;
end;

function TNtxObjectAttributes.UseAttributes;
begin
  Result := Duplicate.SetAttributes(Value);
end;

function TNtxObjectAttributes.UseDesiredAccess;
begin
  Result := Duplicate.SetDesiredAccess(Value);
end;

function TNtxObjectAttributes.UseEffectiveOnly;
begin
  Result := Duplicate.SetEffectiveOnly(Value);
end;

function TNtxObjectAttributes.UseImpersonation;
begin
  Result := Duplicate.SetImpersonation(Value);
end;

function TNtxObjectAttributes.UseName;
begin
  Result := Duplicate.SetName(Value);
end;

function TNtxObjectAttributes.UseRoot;
begin
  Result := Duplicate.SetRoot(Value);
end;

function TNtxObjectAttributes.UseSecurity;
begin
  Result := Duplicate.SetSecurity(Value);
end;

function AttributeBuilder;
begin
  if Assigned(Template) then
    Result := Template
  else
    Result := TNtxObjectAttributes.Create;
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
begin
  StackTrace := RtlxCaptureStackTrace(3);
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

{ Stack traces }

function RtlxNextInstruction;
begin
  // Return address of a function is the next instruction for its caller
  Result := ReturnAddress;
end;

function RtlxCaptureStackTrace;
var
  Count, ReturnedCount: Cardinal;
begin
  // Start with a reasonable depth
  Count := 32;
  Result := nil;

  repeat
    SetLength(Result, Count);

    // Capture the trace
    ReturnedCount := RtlCaptureStackBackTrace(FramesToSkip, Count, @Result[0],
      nil);

    if ReturnedCount < Count then
      Break;

    // Retry with twice the depth
    Count := Count shl 1;
  until False;

  // Trim the output
  SetLength(Result, ReturnedCount);
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
  Status := Value.ToNtStatus;
end;

procedure TNtxStatus.FromWin32ErrorOrSuccess;
begin
  if Value = ERROR_SUCCESS then
    Status := STATUS_SUCCESS
  else
    Status := Value.ToNtStatus;
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
  case Status of
    STATUS_NO_MORE_ENTRIES, STATUS_NO_MORE_FILES, STATUS_NO_SUCH_FILE:
      Target.Status := STATUS_SUCCESS;
  end;
end;

procedure TNtxStatus.SetLocation;
begin
  LastCall := Default(TLastCallInfo);
  LastCall.Location := Value;
end;

{ TGroup }

class function TGroup.From;
begin
  Result.Sid := Sid;
  Result.Attributes := Attributes;
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

  if Status.IsWin32 then
    case Status.Win32Error of
      ERROR_INSUFFICIENT_BUFFER, ERROR_MORE_DATA,
      ERROR_BAD_LENGTH: ; // Pass through
    else
      Exit;
    end
  else
  case Status.Status of
    STATUS_INFO_LENGTH_MISMATCH, STATUS_BUFFER_TOO_SMALL,
    STATUS_BUFFER_OVERFLOW: ;// Pass through
  else
    Exit;
  end;

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

{ Helper functions }

function StringSizeNoZero;
begin
  Result := Length(S) * SizeOf(WideChar);
end;

function StringSizeZero;
begin
  Result := Succ(Length(S)) * SizeOf(WideChar);
end;

procedure MarshalString;
begin
  Move(PWideChar(Source)^, Buffer^, StringSizeZero(Source));
end;

procedure MarshalUnicodeString;
begin
  Target.Length := StringSizeNoZero(Source);
  Target.MaximumLength := StringSizeZero(Source);
  Target.Buffer := Buffer;
  Move(PWideChar(Source)^, Buffer^, StringSizeZero(Source));
end;

function RefStrOrNil;
begin
  if S <> '' then
    Result := PWideChar(S)
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

function RtlxDelayFreeUnicodeString;
begin
  Result := Auto.Delay(
    procedure
    begin
      RtlFreeUnicodeString(Buffer);
    end
  );
end;

function RtlxDelayFreeSid;
begin
  Result := Auto.Delay(
    procedure
    begin
      RtlFreeSid(Buffer);
    end
  );
end;

function AdvxDelayLocalFree;
begin
  Result := Auto.Delay(
    procedure
    begin
      LocalFree(Buffer);
    end
  );
end;

end.
