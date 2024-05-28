unit NtUtils.Threads;

{
  This module provides functions for working with threads via Native API.
}

interface

uses
  Ntapi.WinNt, Ntapi.ntdef, Ntapi.ntpsapi, Ntapi.ntrtl, Ntapi.ntseapi,
  Ntapi.ntpebteb, Ntapi.Versions, NtUtils, DelphiUtils.AutoEvents;

const
  // Ntapi.ntpsapi
  NtCurrentProcess = THandle(-1);
  NtCurrentThread = THandle(-2);

  THREAD_READ_TEB = THREAD_GET_CONTEXT or THREAD_SET_CONTEXT;

  // For suspend/resume via state change
  THREAD_CHANGE_STATE = THREAD_SET_INFORMATION or THREAD_SUSPEND_RESUME;

type
  TThreadInfo = record
    ClientID: TClientId;
    TebAddress: PTeb;
  end;
  PThreadInfo = ^TThreadInfo;

  TThreadApcOptions = set of (
    apcForceSignal, // Use special user APCs when possible (Win 10 RS5+)
    apcWoW64        // Queue a WoW64 APC
  );

{ Opening }

// Get a pseudo-handle to the current thread
function NtxCurrentThread: IHandle;

// Open a thread (always succeeds for the current PID)
[RequiredPrivilege(SE_DEBUG_PRIVILEGE, rpForBypassingChecks)]
function NtxOpenThread(
  out hxThread: IHandle;
  TID: TThreadId;
  DesiredAccess: TThreadAccessMask;
  HandleAttributes: TObjectAttributesFlags = 0;
  [opt] PID: TProcessId = 0
): TNtxStatus;

// Reopen a handle to the current thread with the specific access
function NtxOpenCurrentThread(
  out hxThread: IHandle;
  DesiredAccess: TThreadAccessMask = MAXIMUM_ALLOWED;
  HandleAttributes: TObjectAttributesFlags = 0
): TNtxStatus;

// Open the next accessible thread in the process
[RequiredPrivilege(SE_DEBUG_PRIVILEGE, rpForBypassingChecks)]
function NtxGetNextThread(
  [Access(PROCESS_QUERY_INFORMATION)] hProcess: THandle;
  [opt] var hxThread: IHandle; // use nil to start
  DesiredAccess: TThreadAccessMask;
  HandleAttributes: TObjectAttributesFlags = 0
): TNtxStatus;

// Make a for-in iterator for enumerating process thread via NtGetNextThread.
// Note: when the Status parameter is not set, the function might raise
// exceptions during enumeration.
function NtxIterateGetNextThread(
  [out, opt] Status: PNtxStatus;
  [Access(PROCESS_QUERY_INFORMATION)] const hxProcess: IHandle;
  DesiredAccess: TThreadAccessMask;
  HandleAttributes: TObjectAttributesFlags = 0
): IEnumerable<IHandle>;

// Open a process containing a thread
[RequiredPrivilege(SE_DEBUG_PRIVILEGE, rpForBypassingChecks)]
function NtxOpenProcessByThreadId(
  out hxProcess: IHandle;
  TID: TThreadId;
  DesiredAccess: TProcessAccessMask;
  HandleAttributes: TObjectAttributesFlags = 0
): TNtxStatus;

{ Querying/Setting }

// Query variable-size information
function NtxQueryThread(
  [Access(THREAD_QUERY_INFORMATION)] hThread: THandle;
  InfoClass: TThreadInfoClass;
  out xMemory: IMemory;
  InitialBuffer: Cardinal = 0;
  [opt] GrowthMethod: TBufferGrowthMethod = nil
): TNtxStatus;

// Set variable-size information
[RequiredPrivilege(SE_DEBUG_PRIVILEGE, rpSometimes)]
[RequiredPrivilege(SE_INCREASE_BASE_PRIORITY_PRIVILEGE, rpSometimes)]
function NtxSetThread(
  [Access(THREAD_SET_INFORMATION)] hThread: THandle;
  InfoClass: TThreadInfoClass;
  [in] Buffer: Pointer;
  BufferSize: Cardinal
): TNtxStatus;

type
  NtxThread = class abstract
    // Query fixed-size information
    class function Query<T>(
      [Access(THREAD_QUERY_INFORMATION)] hThread: THandle;
      InfoClass: TThreadInfoClass;
      out Buffer: T
    ): TNtxStatus; static;

    // Set fixed-size information
    [RequiredPrivilege(SE_DEBUG_PRIVILEGE, rpSometimes)]
    [RequiredPrivilege(SE_INCREASE_BASE_PRIORITY_PRIVILEGE, rpSometimes)]
    class function &Set<T>(
      [Access(THREAD_SET_INFORMATION)] hThread: THandle;
      InfoClass: TThreadInfoClass;
      const Buffer: T
    ): TNtxStatus; static;

    // Read a portion of thread's TEB
    class function ReadTeb<T>(
      [Access(THREAD_READ_TEB)] hThread: THandle;
      out Buffer: T;
      Offset: Cardinal = 0
    ): TNtxStatus; static;
  end;

// Assign a thread a name
function NtxQueryNameThread(
  [Access(THREAD_QUERY_LIMITED_INFORMATION)] hThread: THandle;
  out Name: String
): TNtxStatus;

// Assign a thread a name
function NtxSetNameThread(
  [Access(THREAD_SET_LIMITED_INFORMATION)] hThread: THandle;
  const Name: String
): TNtxStatus;

// Read content of thread's TEB
function NtxReadTebThread(
  [Access(THREAD_READ_TEB)] hThread: THandle;
  Offset: Cardinal;
  Size: Cardinal;
  out Memory: IMemory
): TNtxStatus;

// Query last syscall issued by a thread
function NtxQueryLastSyscallThread(
  [Access(THREAD_GET_CONTEXT)] hThread: THandle;
  out LastSyscall: TThreadLastSyscall
): TNtxStatus;

// Query exit status of a thread
function NtxQueryExitStatusThread(
  [Access(THREAD_QUERY_LIMITED_INFORMATION)] hThread: THandle;
  out ExitStatus: NTSTATUS
): TNtxStatus;

{ Manipulation }

// Queue user APC to a thread
function NtxQueueApcThreadEx(
  [Access(THREAD_SET_CONTEXT)] hThread: THandle;
  Routine: TPsApcRoutine;
  [in, opt] Argument1: Pointer = nil;
  [in, opt] Argument2: Pointer = nil;
  [in, opt] Argument3: Pointer = nil;
  Options: TThreadApcOptions = []
): TNtxStatus;

// Get thread context
function NtxGetContextThread(
  [Access(THREAD_GET_CONTEXT)] hThread: THandle;
  FlagsToQuery: TContextFlags;
  out Context: IContext
): TNtxStatus;

// Set thread context
function NtxSetContextThread(
  [Access(THREAD_SET_CONTEXT)] hThread: THandle;
  [in] Context: PContext
): TNtxStatus;

// Suspend a thread
function NtxSuspendThread(
  [Access(THREAD_SUSPEND_RESUME)] hThread: THandle;
  [out, opt] PreviousSuspendCount: PCardinal = nil
): TNtxStatus;

// Resume a thread
function NtxResumeThread(
  [Access(THREAD_SUSPEND_RESUME)] hThread: THandle;
  [out, opt] PreviousSuspendCount: PCardinal = nil
): TNtxStatus;

// Make an alertable thread alerted
function NtxAlertThread(
  [Access(THREAD_ALERT)] hThread: THandle
): TNtxStatus;

// Resume a thread into an alerted state
function NtxAlertResumeThread(
  [Access(THREAD_SUSPEND_RESUME)] hThread: THandle;
  [out, opt] PreviousSuspendCount: PCardinal = nil
): TNtxStatus;

// Terminate a thread
function NtxTerminateThread(
  [Access(THREAD_TERMINATE)] hThread: THandle;
  ExitStatus: NTSTATUS
): TNtxStatus;

// Resume a thread when the object goes out of scope
function NtxDelayedResumeThread(
  [Access(THREAD_SUSPEND_RESUME)] const hxThread: IHandle
): IAutoReleasable;

// Resume a thread into an alerted state when the object goes out of scope
function NtxDelayedAlertResumeThread(
  [Access(THREAD_SUSPEND_RESUME)] const hxThread: IHandle
): IAutoReleasable;

// Terminate a thread when the object goes out of scope
function NtxDelayedTerminateThread(
  [Access(THREAD_TERMINATE)] const hxThread: IHandle;
  ExitStatus: NTSTATUS
): IAutoReleasable;

// Create a thread state change object
[MinOSVersion(OsWin11)]
function NtxCreateThreadState(
  out hxThreadState: IHandle;
  [Access(THREAD_CHANGE_STATE)] hThread: THandle;
  [opt] const ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

// Suspend or resume a thread via state change
[MinOSVersion(OsWin11)]
function NtxChangeStateThread(
  [Access(THREAD_STATE_CHANGE_STATE)] hThreadState: THandle;
  [Access(THREAD_CHANGE_STATE)] hThread: THandle;
  Action: TThreadStateChangeType
): TNtxStatus;

// Suspend a thread using the best method and resume it automatically later
function NtxSuspendThreadAuto(
  [Access(THREAD_CHANGE_STATE)] const hxThread: IHandle;
  out Reverter: IAutoReleasable
): TNtxStatus;

// Temporarily suspend all threads in the current process except for the caller
function RtlxSuspendAllThreadsAuto: IAutoReleasable;

{ Creation }

// Create a thread in a process via a legacy syscall
function NtxCreateThread(
  out hxThread: IHandle;
  [Access(PROCESS_CREATE_THREAD)] hProcess: THandle;
  [in] const Context: TContext;
  [in] const InitialTeb: TInitialTeb;
  CreateSuspended: Boolean;
  [opt] const ObjectAttributes: IObjectAttributes = nil;
  [out, opt] ThreadInfo: PThreadInfo = nil
): TNtxStatus;

// Create a thread in a process
function NtxCreateThreadEx(
  out hxThread: IHandle;
  [Access(PROCESS_CREATE_THREAD)] hProcess: THandle;
  StartRoutine: TUserThreadStartRoutine;
  [in, opt] Argument: Pointer;
  CreateFlags: TThreadCreateFlags = 0;
  ZeroBits: NativeUInt = 0;
  StackSize: NativeUInt = 0;
  MaxStackSize: NativeUInt = 0;
  [opt] const ObjectAttributes: IObjectAttributes = nil;
  [out, opt] ThreadInfo: PThreadInfo = nil
): TNtxStatus;

// Create a thread in a process
function RtlxCreateThread(
  out hxThread: IHandle;
  [Access(PROCESS_CREATE_THREAD)] hProcess: THandle;
  StartRoutine: TUserThreadStartRoutine;
  [in, opt] Parameter: Pointer;
  CreateSuspended: Boolean = False
): TNtxStatus;

// Subscribe to thread creation/termination notifications
[ThreadSafe]
function RtlxSubscribeThreadNotification(
  Callback: TEventCallback<TDllReason>
): IAutoReleasable;

implementation

uses
  Ntapi.ntobapi, Ntapi.ntmmapi, Ntapi.ntldr, NtUtils.Objects,
  NtUtils.Ldr, NtUtils.Processes, DelphiUtils.AutoObjects;

{$BOOLEVAL OFF}
{$IFOPT R+}{$DEFINE R+}{$ENDIF}
{$IFOPT Q+}{$DEFINE Q+}{$ENDIF}

function NtxCurrentThread;
begin
  Result := Auto.RefHandle(NtCurrentThread);
end;

function NtxOpenThread;
var
  hThread: THandle;
  ClientId: TClientId;
  ObjAttr: TObjectAttributes;
begin
  if (TID = NtCurrentThreadId) and
    not BitTest(DesiredAccess and ACCESS_SYSTEM_SECURITY) then
  begin
    // Always succeed on the current thread
    hxThread := NtxCurrentThread;
    Exit(NtxSuccess);
  end;

  InitializeObjectAttributes(ObjAttr, nil, HandleAttributes);
  ClientId.UniqueProcess := PID;
  ClientId.UniqueThread := TID;

  Result.Location := 'NtOpenThread';
  Result.LastCall.OpensForAccess(DesiredAccess);

  Result.Status := NtOpenThread(hThread, DesiredAccess, ObjAttr, ClientId);

  if Result.IsSuccess then
    hxThread := Auto.CaptureHandle(hThread);
end;

function NtxOpenCurrentThread;
var
  hThread: THandle;
  Flags: TDuplicateOptions;
begin
  // Duplicating the pseudo-handle is more reliable then opening thread by TID

  if BitTest(DesiredAccess and MAXIMUM_ALLOWED) and
    not BitTest(DesiredAccess and ACCESS_SYSTEM_SECURITY) then
  begin
    Flags := DUPLICATE_SAME_ACCESS;
    DesiredAccess := 0;
  end
  else
    Flags := 0;

  Result.Location := 'NtDuplicateObject';
  Result.LastCall.OpensForAccess(DesiredAccess);
  Result.Status := NtDuplicateObject(NtCurrentProcess, NtCurrentThread,
    NtCurrentProcess, hThread, DesiredAccess, HandleAttributes, Flags);

  if Result.IsSuccess then
    hxThread := Auto.CaptureHandle(hThread);
end;

function NtxGetNextThread;
var
  hThread, hNewThread: THandle;
begin
  if Assigned(hxThread) then
    hThread := hxThread.Handle
  else
    hThread := 0;

  Result.Location := 'NtGetNextThread';
  Result.LastCall.Expects<TProcessAccessMask>(PROCESS_QUERY_INFORMATION);
  Result.LastCall.OpensForAccess(DesiredAccess);

  Result.Status := NtGetNextThread(hProcess, hThread, DesiredAccess,
    HandleAttributes, 0, hNewThread);

  if Result.IsSuccess then
    hxThread := Auto.CaptureHandle(hNewThread);
end;

function NtxIterateGetNextThread;
var
  hxThread: IHandle;
begin
  hxThread := nil;

  Result := NtxAuto.Iterate<IHandle>(Status,
    function (out Current: IHandle): TNtxStatus
    begin
      // Advance to the next thread handle
      Result := NtxGetNextThread(hxProcess.Handle, hxThread, DesiredAccess,
        HandleAttributes);

      if not Result.IsSuccess then
        Exit;

      Current := hxThread;
    end
  );
end;

function NtxOpenProcessByThreadId;
var
  hxThread: IHandle;
  Info: TThreadBasicInformation;
begin
  Result := NtxOpenThread(hxThread, TID, THREAD_QUERY_LIMITED_INFORMATION);

  if not Result.IsSuccess then
    Exit;

  Result := NtxThread.Query(hxThread.Handle, ThreadBasicInformation, Info);

  if not Result.IsSuccess then
    Exit;

  Result := NtxOpenProcess(hxProcess, Info.ClientId.UniqueProcess,
    DesiredAccess, HandleAttributes);
end;

function NtxQueryThread;
var
  Required: Cardinal;
begin
  Result.Location := 'NtQueryInformationThread';
  Result.LastCall.UsesInfoClass(InfoClass, icQuery);
  Result.LastCall.Expects(ExpectedThreadQueryAccess(InfoClass));

  xMemory := Auto.AllocateDynamic(InitialBuffer);
  repeat
    Required := 0;
    Result.Status := NtQueryInformationThread(hThread, InfoClass,
      xMemory.Data, xMemory.Size, @Required);
  until not NtxExpandBufferEx(Result, xMemory, Required, GrowthMethod);
end;

function NtxSetThread;
begin
  Result.Location := 'NtSetInformationThread';
  Result.LastCall.UsesInfoClass(InfoClass, icSet);
  Result.LastCall.Expects(ExpectedThreadSetAccess(InfoClass));
  Result.LastCall.ExpectedPrivilege := ExpectedThreadSetPrivilege(InfoClass);

  // Additional expected access
  case InfoClass of
    ThreadImpersonationToken:
      Result.LastCall.Expects<TTokenAccessMask>(TOKEN_IMPERSONATE);

    ThreadCpuAccountingInformation:
      Result.LastCall.Expects<TSessionAccessMask>(SESSION_MODIFY_ACCESS);

    ThreadAttachContainer:
      Result.LastCall.Expects<TJobObjectAccessMask>(JOB_OBJECT_IMPERSONATE);
  end;

  Result.Status := NtSetInformationThread(hThread, InfoClass, Buffer,
    BufferSize);
end;

class function NtxThread.Query<T>;
begin
  Result.Location := 'NtQueryInformationThread';
  Result.LastCall.UsesInfoClass(InfoClass, icQuery);
  Result.LastCall.Expects(ExpectedThreadQueryAccess(InfoClass));

  Result.Status := NtQueryInformationThread(hThread, InfoClass, @Buffer,
    SizeOf(Buffer), nil);
end;

class function NtxThread.ReadTeb<T>;
var
  TebInfo: TThreadTebInformation;
begin
  TebInfo.TebInformation := @Buffer;
  TebInfo.TebOffset := Offset;
  TebInfo.BytesToRead := SizeOf(Buffer);

  Result := NtxThread.Query(hThread, ThreadTebInformation, TebInfo);
end;

class function NtxThread.&Set<T>;
begin
  Result := NtxSetThread(hThread, InfoClass, @Buffer, SizeOf(Buffer));
end;

function NtxQueryNameThread;
var
  Buffer: IMemory<PNtUnicodeString>;
begin
  Result := NtxQueryThread(hThread, ThreadNameInformation, IMemory(Buffer));

  if Result.IsSuccess then
    Name := Buffer.Data.ToString;
end;

function NtxSetNameThread;
var
  NameStr: TNtUnicodeString;
begin
  Result := RtlxInitUnicodeString(NameStr, Name);

  if not Result.IsSuccess then
    Exit;

  Result := NtxThread.Set(hThread, ThreadNameInformation, NameStr);
end;

function NtxReadTebThread;
var
  TebInfo: TThreadTebInformation;
begin
  Memory := Auto.AllocateDynamic(Size);

  // Describe the read request
  TebInfo.TebInformation := Memory.Data;
  TebInfo.TebOffset := Offset;
  TebInfo.BytesToRead := Size;

  // Query TEB content
  Result := NtxThread.Query(hThread, ThreadTebInformation, TebInfo);

  if not Result.IsSuccess then
    Memory := nil;
end;

function NtxQueryLastSyscallThread;
var
  LastSyscallWin7: TThreadLastSyscallWin7;
begin
  if RtlOsVersionAtLeast(OsWin8) then
  begin
    LastSyscall := Default(TThreadLastSyscall);
    Result := NtxThread.Query(hThread, ThreadLastSystemCall, LastSyscall);
  end
  else
  begin
    LastSyscallWin7 := Default(TThreadLastSyscallWin7);
    Result := NtxThread.Query(hThread, ThreadLastSystemCall, LastSyscallWin7);

    if Result.IsSuccess then
    begin
      LastSyscall.FirstArgument := LastSyscallWin7.FirstArgument;
      LastSyscall.SystemCallNumber := LastSyscallWin7.SystemCallNumber;
      LastSyscall.WaitTime := 0;
    end;
  end;
end;

function NtxQueryExitStatusThread;
var
  Info: TThreadBasicInformation;
begin
  Result := NtxThread.Query(hThread, ThreadBasicInformation, Info);

  if Result.IsSuccess then
    ExitStatus := Info.ExitStatus;
end;

function NtxQueueApcThreadEx;
var
  Flags: THandle;
begin
  if (apcForceSignal in Options) and RtlOsVersionAtLeast(OsWin10RS5) then
    Flags := APC_FORCE_THREAD_SIGNAL
  else
    Flags := 0;

{$IFDEF Win64}
  // Encode the pointer the same way RtlQueueApcWow64Thread does
  if apcWoW64 in Options then
    UIntPtr(@Routine) := UIntPtr(-IntPtr(@Routine)) shl 2;
{$ENDIF}

  Result.Location := 'NtQueueApcThreadEx';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_SET_CONTEXT);

  Result.Status := NtQueueApcThreadEx(hThread, Flags, Routine, Argument1,
    Argument2, Argument3);
end;

function NtxGetContextThread;
begin
  IMemory(Context) := Auto.AllocateDynamic(SizeOf(TContext));
  Context.Data.ContextFlags := FlagsToQuery;

  Result.Location := 'NtGetContextThread';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_GET_CONTEXT);
  Result.Status := NtGetContextThread(hThread, Context.Data);
end;

function NtxSetContextThread;
begin
  Result.Location := 'NtSetContextThread';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_SET_CONTEXT);
  Result.Status := NtSetContextThread(hThread, Context);
end;

function NtxSuspendThread;
begin
  Result.Location := 'NtSuspendThread';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_SUSPEND_RESUME);
  Result.Status := NtSuspendThread(hThread, PreviousSuspendCount);
end;

function NtxResumeThread;
begin
  Result.Location := 'NtResumeThread';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_SUSPEND_RESUME);
  Result.Status := NtResumeThread(hThread, PreviousSuspendCount);
end;

function NtxAlertThread;
begin
  Result.Location := 'NtAlertThread';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_ALERT);
  Result.Status := NtAlertThread(hThread);
end;

function NtxAlertResumeThread;
begin
  Result.Location := 'NtAlertResumeThread';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_SUSPEND_RESUME);
  Result.Status := NtAlertResumeThread(hThread, PreviousSuspendCount);
end;

function NtxTerminateThread;
begin
  Result.Location := 'NtTerminateThread';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_TERMINATE);
  Result.Status := NtTerminateThread(hThread, ExitStatus);
end;

function NtxDelayedResumeThread;
begin
  Result := Auto.Delay(
    procedure
    begin
      NtxResumeThread(hxThread.Handle);
    end
  );
end;

function NtxDelayedAlertResumeThread;
begin
  Result := Auto.Delay(
    procedure
    begin
      NtxAlertResumeThread(hxThread.Handle);
    end
  );
end;

function NtxDelayedTerminateThread;
begin
  Result := Auto.Delay(
    procedure
    begin
      NtxTerminateThread(hxThread.Handle, ExitStatus);
    end
  );
end;

function NtxCreateThreadState;
var
  ObjAttr: PObjectAttributes;
  hThreadState: THandle;
begin
  Result := LdrxCheckDelayedImport(delayed_ntdll,
    delayed_NtCreateThreadStateChange);

  if not Result.IsSuccess then
    Exit;

  Result := AttributesRefOrNil(ObjAttr, ObjectAttributes);

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'NtCreateThreadStateChange';
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_SET_INFORMATION);

  Result.Status := NtCreateThreadStateChange(
    hThreadState,
    AccessMaskOverride(THREAD_STATE_CHANGE_STATE, ObjectAttributes),
    ObjAttr,
    hThread,
    0
  );

  if Result.IsSuccess then
    hxThreadState := Auto.CaptureHandle(hThreadState);
end;

function NtxChangeStateThread;
begin
  Result := LdrxCheckDelayedImport(delayed_ntdll, delayed_NtChangeThreadState);

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'NtChangeThreadState';
  Result.LastCall.UsesInfoClass(Action, icPerform);
  Result.LastCall.Expects<TThreadStateAccessMask>(THREAD_STATE_CHANGE_STATE);
  Result.LastCall.Expects<TThreadAccessMask>(THREAD_SUSPEND_RESUME);

  Result.Status := NtChangeThreadState(hThreadState, hThread, Action, nil,
    0, 0);
end;

function NtxSuspendThreadAuto;
var
  hxThreadState: IHandle;
begin
  // Try state change-based suspension first
  Result := NtxCreateThreadState(hxThreadState, hxThread.Handle);

  if Result.IsSuccess then
  begin
    Result := NtxChangeStateThread(hxThreadState.Handle, hxThread.Handle,
      ThreadStateChangeSuspend);

    if Result.IsSuccess then
    begin
      // Releasing the state change handle will resume the thread
      Reverter := hxThreadState;
      Exit;
    end;
  end;

  // Fall back to classic suspension
  Result := NtxSuspendThread(hxThread.Handle);

  if Result.IsSuccess then
    Reverter := NtxDelayedResumeThread(hxThread);
end;

function RtlxSuspendAllThreadsAuto;
var
  Reverter: IAutoReleasable;
  Reverters: TArray<IAutoReleasable>;
  BasicInfo: TThreadBasicInformation;
  hxThread: IHandle;
  Status: TNtxStatus;
begin
  hxThread := nil;
  Reverters := nil;

  while NtxGetNextThread(NtCurrentProcess, hxThread,
    THREAD_SUSPEND_RESUME or THREAD_QUERY_LIMITED_INFORMATION).IsSuccess do
  begin
    // Determine thread ID
    Status := NtxThread.Query(hxThread.Handle, ThreadBasicInformation,
      BasicInfo);

    if not Status.IsSuccess then
      Continue;

    // Skip the current thread
    if BasicInfo.ClientId.UniqueThread = NtCurrentThreadId then
      Continue;

    // Suspend and save the reverter
    Status := NtxSuspendThreadAuto(hxThread, Reverter);

    if Status.IsSuccess then
    begin
      SetLength(Reverters, Length(Reverters) + 1);
      Reverters[High(Reverters)] := Reverter;
    end;
  end;

  Result := Auto.Copy(Reverters);
end;

function NtxCreateThread;
var
  ObjAttr: PObjectAttributes;
  hThread: THandle;
  ClientId: TClientId;
  BasicInfo: TThreadBasicInformation;
begin
  Result := AttributesRefOrNil(ObjAttr, ObjectAttributes);

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'NtCreateThread';
  Result.LastCall.Expects<TProcessAccessMask>(PROCESS_CREATE_THREAD);
  Result.Status := NtCreateThread(
    hThread,
    AccessMaskOverride(THREAD_ALL_ACCESS, ObjectAttributes),
    ObjAttr,
    hProcess,
    ClientId,
    Context,
    InitialTeb,
    CreateSuspended
  );

  if not Result.IsSuccess then
    Exit;

  hxThread := Auto.CaptureHandle(hThread);

  if Assigned(ThreadInfo) then
  begin
    ThreadInfo.ClientID := ClientId;

    // Determine the TEB address when possible
    if NtxThread.Query(hxThread.Handle, ThreadBasicInformation,
      BasicInfo).IsSuccess then
      ThreadInfo.TebAddress := BasicInfo.TebBaseAddress
    else
      ThreadInfo.TebAddress := nil;
  end;
end;

function NtxCreateThreadEx;
var
  ObjAttr: PObjectAttributes;
  hThread: THandle;
  PsAttributes: IMemory<PPsAttributeList>;
  PsAttribute: PPsAttribute;
begin
  Result := AttributesRefOrNil(ObjAttr, ObjectAttributes);

  if not Result.IsSuccess then
    Exit;

  if Assigned(ThreadInfo) then
  begin
    IMemory(PsAttributes) := Auto.AllocateDynamic(
      TPsAttributeList.SizeOfCount(2));

    PsAttributes.Data.TotalLength := PsAttributes.Size;
    PsAttribute := @PsAttributes.Data.Attributes[0];

    // Retrieve the client ID
    PsAttribute.Attribute := PS_ATTRIBUTE_CLIENT_ID;
    PsAttribute.Size := SizeOf(TClientId);
    Pointer(PsAttribute.Value) := @ThreadInfo.ClientId;
    Inc(PsAttribute);

    // Retrieve the TEB address
    PsAttribute.Attribute := PS_ATTRIBUTE_TEB_ADDRESS;
    PsAttribute.Size := SizeOf(PTeb);
    Pointer(PsAttribute.Value) := @ThreadInfo.TebAddress;
  end
  else
    PsAttributes := nil;

  Result.Location := 'NtCreateThreadEx';
  Result.LastCall.Expects<TProcessAccessMask>(PROCESS_CREATE_THREAD);

  Result.Status := NtCreateThreadEx(
    hThread,
    AccessMaskOverride(THREAD_ALL_ACCESS, ObjectAttributes),
    ObjAttr,
    hProcess,
    StartRoutine,
    Argument,
    CreateFlags,
    ZeroBits,
    StackSize,
    MaxStackSize,
    Auto.RefOrNil<PPsAttributeList>(PsAttributes)
  );

  if Result.IsSuccess then
    hxThread := Auto.CaptureHandle(hThread);
end;

function RtlxCreateThread;
var
  hThread: THandle;
begin
  Result.Location := 'RtlCreateUserThread';
  Result.LastCall.Expects<TProcessAccessMask>(PROCESS_CREATE_THREAD);

  Result.Status := RtlCreateUserThread(hProcess, nil, CreateSuspended, 0, 0, 0,
    StartRoutine, Parameter, hThread, nil);

  if Result.IsSuccess then
    hxThread := Auto.CaptureHandle(hThread);
end;

var
  // A list of registered thread creation/termination callbacks
  RtlxpThreadCallbacks: TAutoEvent<TDllReason>;

// A dispatcher callback that is binary compatible with DllMain routines
function RtlxpThreadCallbackDispatcher(
  [in] DllHandle: Pointer;
  Reason: TDllReason;
  [in, opt] Context: PContext
): Boolean; stdcall;
begin
  RtlxpThreadCallbacks.Invoke(Reason);
  Result := True;
end;

function RtlxSubscribeThreadNotification;
var
  Lock: IAutoReleasable;
begin
  // The module loader invokes DLL entrypoints for thread attaching/detaching.
  // Unfortunately, there doesn't seem to be alternative mechanisms available
  // for non-DLL code. As a solution, adjust the PEB Ldr data and pretend
  // to be ntdll's entrypoint (which is unused) to receive notifications.

  LdrxAcquireLoaderLock(Lock);
  hNtdll.EntryPoint := @RtlxpThreadCallbackDispatcher;
  hNtdll.Flags := hNtdll.Flags or LDRP_PROCESS_ATTACH_CALLED;
  Lock := nil;

  Result := RtlxpThreadCallbacks.Subscribe(Callback);
end;

end.
