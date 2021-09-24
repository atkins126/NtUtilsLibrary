unit Ntapi.WinNt;

{
  This file includes widely used type definitions for Win32 and Native API.
  For sources see SDK::winnt.h
}

interface

{$MINENUMSIZE 4}

uses
  DelphiApi.Reflection;

const
  kernelbase = 'kernelbase.dll';
  kernel32 = 'kernel32.dll';
  advapi32 = 'advapi32.dll';

  MAX_HANDLE = $FFFFFF; // handle table maximum
  MAX_UINT = $FFFFFFFF;

  MAXIMUM_WAIT_OBJECTS = 64;

  NT_INFINITE = $8000000000000000; // maximum possible relative timeout
  MILLISEC = -10000; // 100ns in 1 ms in relative time

  // Thread context geting/setting flags
  CONTEXT_i386 = $00010000;

  CONTEXT_CONTROL = CONTEXT_i386 or $00000001;  // SS:SP, CS:IP, FLAGS, BP
  CONTEXT_INTEGER = CONTEXT_i386 or $00000002;  // AX, BX, CX, DX, SI, DI
  CONTEXT_SEGMENTS = CONTEXT_i386 or $00000004; // DS, ES, FS, GS
  CONTEXT_FLOATING_POINT = CONTEXT_i386 or $00000008;     // 387 state
  CONTEXT_DEBUG_REGISTERS = CONTEXT_i386 or $00000010;    // DB 0-3,6,7
  CONTEXT_EXTENDED_REGISTERS = CONTEXT_i386 or $00000020; // cpu specific extensions

  CONTEXT_FULL = CONTEXT_CONTROL or CONTEXT_INTEGER or CONTEXT_SEGMENTS;
  CONTEXT_ALL = CONTEXT_FULL or CONTEXT_FLOATING_POINT or
    CONTEXT_DEBUG_REGISTERS or CONTEXT_EXTENDED_REGISTERS;

  CONTEXT_XSTATE = CONTEXT_i386 or $00000040;

  CONTEXT_EXCEPTION_ACTIVE = $08000000;
  CONTEXT_SERVICE_ACTIVE = $10000000;
  CONTEXT_EXCEPTION_REQUEST = $40000000;
  CONTEXT_EXCEPTION_REPORTING = $80000000;

  // EFLAGS register bits
  EFLAGS_CF = $0001; // Carry
  EFLAGS_PF = $0004; // Parity
  EFLAGS_AF = $0010; // Auxiliary Carry
  EFLAGS_ZF = $0040; // Zero
  EFLAGS_SF = $0080; // Sign
  EFLAGS_TF = $0100; // Trap
  EFLAGS_IF = $0200; // Interrupt
  EFLAGS_DF = $0400; // Direction
  EFLAGS_OF = $0800; // Overflow

  // Exception flags
  EXCEPTION_NONCONTINUABLE = $01;
  EXCEPTION_UNWINDING = $02;
  EXCEPTION_EXIT_UNWIND = $04;
  EXCEPTION_STACK_INVALID = $08;
  EXCEPTION_NESTED_CALL = $10;
  EXCEPTION_TARGET_UNWIND = $20;
  EXCEPTION_COLLIDED_UNWIND = $40;

  EXCEPTION_UNWIND = EXCEPTION_UNWINDING or EXCEPTION_EXIT_UNWIND or
    EXCEPTION_TARGET_UNWIND or EXCEPTION_COLLIDED_UNWIND;

  // Access masks
  _DELETE = $00010000;      // SDDL: DE
  READ_CONTROL = $00020000; // SDDL: RC
  WRITE_DAC = $00040000;    // SDDL: WD
  WRITE_OWNER = $00080000;  // SDDL: WO
  SYNCHRONIZE = $00100000;  // SDDL: SY

  STANDARD_RIGHTS_REQUIRED = _DELETE or READ_CONTROL or WRITE_DAC or WRITE_OWNER;
  STANDARD_RIGHTS_READ = READ_CONTROL;
  STANDARD_RIGHTS_WRITE = READ_CONTROL;
  STANDARD_RIGHTS_EXECUTE = READ_CONTROL;
  STANDARD_RIGHTS_ALL = STANDARD_RIGHTS_REQUIRED or SYNCHRONIZE;
  SPECIFIC_RIGHTS_ALL = $0000FFFF;

  ACCESS_SYSTEM_SECURITY = $01000000; // SDDL: AS
  MAXIMUM_ALLOWED = $02000000;        // SDDL: MA

  GENERIC_READ = Cardinal($80000000); // SDDL: GR
  GENERIC_WRITE = $40000000;          // SDDL: GW
  GENERIC_EXECUTE = $20000000;        // SDDL: GX
  GENERIC_ALL = $10000000;            // SDDL: GA
  GENERIC_RIGHTS_ALL = GENERIC_READ or GENERIC_WRITE or GENERIC_EXECUTE or
    GENERIC_ALL;

  // Masks for annotations
  OBJECT_READ_SECURITY = READ_CONTROL or ACCESS_SYSTEM_SECURITY;
  OBJECT_WRITE_SECURITY = WRITE_DAC or WRITE_OWNER or ACCESS_SYSTEM_SECURITY;

  // SID structure consts
  SID_MAX_SUB_AUTHORITIES = 15;
  SECURITY_MAX_SID_SIZE = 8 + SID_MAX_SUB_AUTHORITIES * SizeOf(Cardinal);
  SECURITY_MAX_SID_STRING_CHARACTERS = 2 + 4 + 15 +
    (11 * SID_MAX_SUB_AUTHORITIES) + 1;

  ACL_REVISION = 2;
  MAX_ACL_SIZE = High(Word) and not (SizeOf(Cardinal) - 1);

  // ACE flags
  OBJECT_INHERIT_ACE = $1;
  CONTAINER_INHERIT_ACE = $2;
  NO_PROPAGATE_INHERIT_ACE = $4;
  INHERIT_ONLY_ACE = $8;
  INHERITED_ACE = $10;
  CRITICAL_ACE_FLAG = $20;               // for access allowed ace
  SUCCESSFUL_ACCESS_ACE_FLAG = $40;      // for audit and alarm aces
  FAILED_ACCESS_ACE_FLAG = $80;          // for audit and alarm aces
  TRUST_PROTECTED_FILTER_ACE_FLAG = $40; // for access filter ace

  // Mandatory policy flags
  SYSTEM_MANDATORY_LABEL_NO_WRITE_UP = $1;
  SYSTEM_MANDATORY_LABEL_NO_READ_UP = $2;
  SYSTEM_MANDATORY_LABEL_NO_EXECUTE_UP = $4;

  // SD version
  SECURITY_DESCRIPTOR_REVISION = 1;

  // SDK::winnt.h & WDK::ntifs.h - security descriptor control
  SE_OWNER_DEFAULTED = $0001;
  SE_GROUP_DEFAULTED = $0002;
  SE_DACL_PRESENT = $0004;
  SE_DACL_DEFAULTED = $0008;
  SE_SACL_PRESENT = $0010;
  SE_SACL_DEFAULTED = $0020;
  SE_DACL_UNTRUSTED = $0040;
  SE_SERVER_SECURITY = $0080;
  SE_DACL_AUTO_INHERIT_REQ = $0100;
  SE_SACL_AUTO_INHERIT_REQ = $0200;
  SE_DACL_AUTO_INHERITED = $0400;
  SE_SACL_AUTO_INHERITED = $0800;
  SE_DACL_PROTECTED = $1000;
  SE_SACL_PROTECTED = $2000;
  SE_RM_CONTROL_VALID = $4000;
  SE_SELF_RELATIVE = $8000;

  // Security information values
  OWNER_SECURITY_INFORMATION = $00000001; // q: RC; s: WO
  GROUP_SECURITY_INFORMATION = $00000002; // q: RC; s: WO
  DACL_SECURITY_INFORMATION = $00000004;  // q: RC; s: WD
  SACL_SECURITY_INFORMATION = $00000008;  // q, s: AS
  LABEL_SECURITY_INFORMATION = $00000010; // q: RC; s: WO
  ATTRIBUTE_SECURITY_INFORMATION = $00000020; // q: RC; s: WD; Win 8+
  SCOPE_SECURITY_INFORMATION = $00000040; // q: RC; s: AS; Win 8+
  PROCESS_TRUST_LABEL_SECURITY_INFORMATION = $00000080; // Win 8.1+
  ACCESS_FILTER_SECURITY_INFORMATION = $00000100; // Win 10 RS2+
  BACKUP_SECURITY_INFORMATION = $00010000; // q: RC | AS; s: WD | WO | AS; Win 8+

  PROTECTED_DACL_SECURITY_INFORMATION = $80000000;   // s: WD
  PROTECTED_SACL_SECURITY_INFORMATION = $40000000;   // s: AS
  UNPROTECTED_DACL_SECURITY_INFORMATION = $20000000; // s: WD
  UNPROTECTED_SACL_SECURITY_INFORMATION = $10000000; // s: AS

  // DLL reasons
  DLL_PROCESS_DETACH = 0;
  DLL_PROCESS_ATTACH = 1;
  DLL_THREAD_ATTACH = 2;
  DLL_THREAD_DETACH = 3;

  // process access masks
  PROCESS_TERMINATE = $0001;
  PROCESS_CREATE_THREAD = $0002;
  PROCESS_SET_SESSIONID = $0004;
  PROCESS_VM_OPERATION = $0008;
  PROCESS_VM_READ = $0010;
  PROCESS_VM_WRITE = $0020;
  PROCESS_DUP_HANDLE = $0040;
  PROCESS_CREATE_PROCESS = $0080;
  PROCESS_SET_QUOTA = $0100;
  PROCESS_SET_INFORMATION = $0200;
  PROCESS_QUERY_INFORMATION = $0400;
  PROCESS_SUSPEND_RESUME = $0800;
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  PROCESS_SET_LIMITED_INFORMATION = $2000;

  PROCESS_ALL_ACCESS = STANDARD_RIGHTS_ALL or SPECIFIC_RIGHTS_ALL;

  // thread access mask
  THREAD_TERMINATE = $0001;
  THREAD_SUSPEND_RESUME = $0002;
  THREAD_ALERT = $0004;
  THREAD_GET_CONTEXT = $0008;
  THREAD_SET_CONTEXT = $0010;
  THREAD_SET_INFORMATION = $0020;
  THREAD_QUERY_INFORMATION = $0040;
  THREAD_SET_THREAD_TOKEN = $0080;
  THREAD_IMPERSONATE = $0100;
  THREAD_DIRECT_IMPERSONATION = $0200;
  THREAD_SET_LIMITED_INFORMATION = $0400;
  THREAD_QUERY_LIMITED_INFORMATION = $0800;
  THREAD_RESUME = $1000;

  THREAD_ALL_ACCESS = STANDARD_RIGHTS_ALL or SPECIFIC_RIGHTS_ALL;

type
  // If range checks are enabled, make sure to wrap all accesses to any-size
  // arrays into a {$R-}/{$R+} block which temporarily disables them.
  ANYSIZE_ARRAY = 0..0;
  TAnysizeArray<T> = array [ANYSIZE_ARRAY] of T;

  TWin32Error = type Cardinal;

  // Absolute times
  [SDKName('LARGE_INTEGER')]
  TLargeInteger = type Int64;
  PLargeInteger = ^TLargeInteger;
  TUnixTime = type Cardinal;

  // Relative times
  [SDKName('ULARGE_INTEGER')]
  TULargeInteger = type UInt64;
  PULargeInteger = ^TULargeInteger;

  [SDKName('LUID')]
  [Hex] TLuid = type UInt64;
  PLuid = ^TLuid;

  TProcessId = type NativeUInt;
  TThreadId = type NativeUInt;
  TProcessId32 = type Cardinal;
  TThreadId32 = type Cardinal;
  TServiceTag = type Cardinal;

  TLogonId = type TLuid;
  TSessionId = type Cardinal;

  PEnvironment = type PWideChar;

  PListEntry = ^TListEntry;
  [SDKName('LIST_ENTRY')]
  TListEntry = record
    Flink: PListEntry;
    Blink: PListEntry;
  end;

  {$ALIGN 16}
  [SDKName('M128A')]
  M128A = record
    Low: UInt64;
    High: Int64;
  end;
  {$ALIGN 8}

  [FlagName(EFLAGS_CF, 'Carry')]
  [FlagName(EFLAGS_PF, 'Parity')]
  [FlagName(EFLAGS_AF, 'Auxiliary Carry')]
  [FlagName(EFLAGS_ZF, 'Zero')]
  [FlagName(EFLAGS_SF, 'Sign')]
  [FlagName(EFLAGS_TF, 'Trap')]
  [FlagName(EFLAGS_IF, 'Interrupt')]
  [FlagName(EFLAGS_DF, 'Direction')]
  [FlagName(EFLAGS_OF, 'Overflow')]
  TEFlags = type Cardinal;

  [FlagName(CONTEXT_ALL, 'All')]
  [FlagName(CONTEXT_FULL, 'Full')]
  [FlagName(CONTEXT_CONTROL, 'Control')]
  [FlagName(CONTEXT_INTEGER, 'General-purpose')]
  [FlagName(CONTEXT_SEGMENTS, 'Segments ')]
  [FlagName(CONTEXT_FLOATING_POINT, 'Floating Point')]
  [FlagName(CONTEXT_DEBUG_REGISTERS, 'Debug Registers')]
  [FlagName(CONTEXT_EXTENDED_REGISTERS, 'Extended Registers')]
  TContextFlags = type Cardinal;

  {$ALIGN 16}
  [Hex]
  TContext64 = record
    PnHome: array [1..6] of UInt64;
    ContextFlags: TContextFlags;
    MxCsr: Cardinal;
    SegCs: Word;
    SegDs: Word;
    SegEs: Word;
    SegFs: Word;
    SegGs: Word;
    SegSs: Word;
    EFlags: TEFlags;
    Dr0: UInt64;
    Dr1: UInt64;
    Dr2: UInt64;
    Dr3: UInt64;
    Dr6: UInt64;
    Dr7: UInt64;
    Rax: UInt64;
    Rcx: UInt64;
    Rdx: UInt64;
    Rbx: UInt64;
    Rsp: UInt64;
    Rbp: UInt64;
    Rsi: UInt64;
    Rdi: UInt64;
    R8: UInt64;
    R9: UInt64;
    R10: UInt64;
    R11: UInt64;
    R12: UInt64;
    R13: UInt64;
    R14: UInt64;
    R15: UInt64;
    Rip: UInt64;
    FloatingPointState: array [0..31] of M128A;
    VectorRegister: array [0..25] of M128A;
    VectorControl: UInt64;
    DebugControl: UInt64;
    LastBranchToRip: UInt64;
    LastBranchFromRip: UInt64;
    LastExceptionToRip: UInt64;
    LastExceptionFromRip: UInt64;
    property Ax: UInt64 read Rax write Rax;
    property Cx: UInt64 read Rcx write Rcx;
    property Dx: UInt64 read Rdx write Rdx;
    property Bx: UInt64 read Rbx write Rbx;
    property Sp: UInt64 read Rsp write Rsp;
    property Bp: UInt64 read Rbp write Rbp;
    property Si: UInt64 read Rsi write Rsi;
    property Di: UInt64 read Rdi write Rdi;
    property Ip: UInt64 read Rip write Rip;
  end;
  PContext64 = ^TContext64;
  {$ALIGN 8}

  [SDKName('FLOATING_SAVE_AREA')]
  TFloatingSaveArea = record
  const
    SIZE_OF_80387_REGISTERS = 80;
  var
    ControlWord: Cardinal;
    StatusWord: Cardinal;
    TagWord: Cardinal;
    ErrorOffset: Cardinal;
    ErrorSelector: Cardinal;
    DataOffset: Cardinal;
    DataSelector: Cardinal;
    RegisterArea: array [0 .. SIZE_OF_80387_REGISTERS - 1] of Byte;
    Cr0NpxState: Cardinal;
  end;

  [Hex]
  TContext32 = record
  const
    MAXIMUM_SUPPORTED_EXTENSION = 512;
  var
    ContextFlags: TContextFlags;
    Dr0: Cardinal;
    Dr1: Cardinal;
    Dr2: Cardinal;
    Dr3: Cardinal;
    Dr6: Cardinal;
    Dr7: Cardinal;
    FloatSave: TFloatingSaveArea;
    SegGs: Cardinal;
    SegFs: Cardinal;
    SegEs: Cardinal;
    SegDs: Cardinal;
    Edi: Cardinal;
    Esi: Cardinal;
    Ebx: Cardinal;
    Edx: Cardinal;
    Ecx: Cardinal;
    Eax: Cardinal;
    Ebp: Cardinal;
    Eip: Cardinal;
    SegCs: Cardinal;
    EFlags: TEFlags;
    Esp: Cardinal;
    SegSs: Cardinal;
    ExtendedRegisters: array [0 .. MAXIMUM_SUPPORTED_EXTENSION - 1] of Byte;
    property Ax: Cardinal read Eax write Eax;
    property Cx: Cardinal read Ecx write Ecx;
    property Dx: Cardinal read Edx write Edx;
    property Bx: Cardinal read Ebx write Ebx;
    property Sp: Cardinal read Esp write Esp;
    property Bp: Cardinal read Ebp write Ebp;
    property Si: Cardinal read Esi write Esi;
    property Di: Cardinal read Edi write Edi;
    property Ip: Cardinal read Eip write Eip;
  end;
  PContext32 = ^TContext32;

  {$IFDEF WIN64}
  TContext = TContext64;
  {$ELSE}
  TContext = TContext32;
  {$ENDIF}
  PContext = ^TContext;

  [FlagName(EXCEPTION_NONCONTINUABLE, 'Non-continuable')]
  [FlagName(EXCEPTION_UNWINDING, 'Unwinding')]
  [FlagName(EXCEPTION_EXIT_UNWIND, 'Exit Unwinding')]
  [FlagName(EXCEPTION_STACK_INVALID, 'Stack Invalid')]
  [FlagName(EXCEPTION_NESTED_CALL, 'Nested Exception Call')]
  [FlagName(EXCEPTION_TARGET_UNWIND, 'Target Unwinding')]
  [FlagName(EXCEPTION_COLLIDED_UNWIND, 'Collided Unwind')]
  TExceptionFlags = type Cardinal;

  PExceptionRecord = ^TExceptionRecord;
  [SDKName('EXCEPTION_RECORD')]
  TExceptionRecord = record
  const
    EXCEPTION_MAXIMUM_PARAMETERS = 15;
  var
    [Hex] ExceptionCode: Cardinal;
    ExceptionFlags: TExceptionFlags;
    ExceptionRecord: PExceptionRecord;
    ExceptionAddress: Pointer;
    NumberParameters: Cardinal;
    ExceptionInformation: array [0 .. EXCEPTION_MAXIMUM_PARAMETERS - 1] of
      NativeUInt;
  end;

  [FriendlyName('object'), ValidMask($FFFFFFFF)]
  [FlagName(READ_CONTROL, 'Read Permissions')]
  [FlagName(WRITE_DAC, 'Write Permissions')]
  [FlagName(WRITE_OWNER, 'Write Owner')]
  [FlagName(SYNCHRONIZE, 'Synchronize')]
  [FlagName(_DELETE, 'Delete')]
  [FlagName(ACCESS_SYSTEM_SECURITY, 'System Security')]
  [FlagName(MAXIMUM_ALLOWED, 'Maximum Allowed')]
  [FlagName(GENERIC_READ, 'Generic Read')]
  [FlagName(GENERIC_WRITE, 'Generic Write')]
  [FlagName(GENERIC_EXECUTE, 'Generic Execute')]
  [FlagName(GENERIC_ALL, 'Generic All')]
  TAccessMask = type Cardinal;

  [SDKName('GENERIC_MAPPING')]
  TGenericMapping = record
    GenericRead: TAccessMask;
    GenericWrite: TAccessMask;
    GenericExecute: TAccessMask;
    GenericAll: TAccessMask;
  end;
  PGenericMapping = ^TGenericMapping;

  [SDKName('SID_IDENTIFIER_AUTHORITY')]
  TSidIdentifierAuthority = record
    Value: array [0..5] of Byte;
    class operator Implicit(const Source: UInt64): TSidIdentifierAuthority;
    class operator Implicit(const Source: TSidIdentifierAuthority): UInt64;
  end;
  PSidIdentifierAuthority = ^TSidIdentifierAuthority;

  [SDKName('SID')]
  TSid = record
   Revision: Byte;
   SubAuthorityCount: Byte;
   IdentifierAuthority: TSidIdentifierAuthority;
   SubAuthority: array [0 .. SID_MAX_SUB_AUTHORITIES - 1] of Cardinal;
  end;
  PSid = ^TSid;

  [SDKName('SID_NAME_USE')]
  [NamingStyle(nsCamelCase, 'SidType'), Range(1)]
  TSidNameUse = (
    SidTypeUndefined = 0,
    SidTypeUser = 1,
    SidTypeGroup = 2,
    SidTypeDomain = 3,
    SidTypeAlias = 4,
    SidTypeWellKnownGroup = 5,
    SidTypeDeletedAccount = 6,
    SidTypeInvalid = 7,
    SidTypeUnknown = 8,
    SidTypeComputer = 9,
    SidTypeLabel = 10,
    SidTypeLogonSession = 11
  );

  [SDKName('ACL')]
  TAcl = record
    AclRevision: Byte;
    Sbz1: Byte;
    AclSize: Word;
    AceCount: Word;
    Sbz2: Word;
  end;
  PAcl = ^TAcl;

  {$MINENUMSIZE 1}
  [NamingStyle(nsSnakeCase, '', 'ACE_TYPE')]
  TAceType = (
    ACCESS_ALLOWED_ACE_TYPE = 0,
    ACCESS_DENIED_ACE_TYPE = 1,
    SYSTEM_AUDIT_ACE_TYPE = 2,
    SYSTEM_ALARM_ACE_TYPE = 3,

    ACCESS_ALLOWED_COMPOUND_ACE_TYPE = 4, // Unknown

    ACCESS_ALLOWED_OBJECT_ACE_TYPE = 5, // Object ace
    ACCESS_DENIED_OBJECT_ACE_TYPE = 6,  // Object ace
    SYSTEM_AUDIT_OBJECT_ACE_TYPE = 7,   // Object ace
    SYSTEM_ALARM_OBJECT_ACE_TYPE = 8,   // Object ace

    ACCESS_ALLOWED_CALLBACK_ACE_TYPE = 9,
    ACCESS_DENIED_CALLBACK_ACE_TYPE = 10,

    ACCESS_ALLOWED_CALLBACK_OBJECT_ACE_TYPE = 11, // Object ace
    ACCESS_DENIED_CALLBACK_OBJECT_ACE_TYPE = 12,  // Object ace

    SYSTEM_AUDIT_CALLBACK_ACE_TYPE = 13,
    SYSTEM_ALARM_CALLBACK_ACE_TYPE = 14,

    SYSTEM_AUDIT_CALLBACK_OBJECT_ACE_TYPE = 15, // Object ace
    SYSTEM_ALARM_CALLBACK_OBJECT_ACE_TYPE = 16, // Object ace

    SYSTEM_MANDATORY_LABEL_ACE_TYPE = 17,
    SYSTEM_RESOURCE_ATTRIBUTE_ACE_TYPE = 18,
    SYSTEM_SCOPED_POLICY_ID_ACE_TYPE = 19,
    SYSTEM_PROCESS_TRUST_LABEL_ACE_TYPE = 20,
    SYSTEM_ACCESS_FILTER_ACE_TYPE = 21
  );
  {$MINENUMSIZE 4}

  TAceTypeSet = set of TAceType;

  [FlagName(OBJECT_INHERIT_ACE, 'Object Inherit')]
  [FlagName(CONTAINER_INHERIT_ACE, 'Container Inherit')]
  [FlagName(NO_PROPAGATE_INHERIT_ACE, 'No Propagate Inherit')]
  [FlagName(INHERIT_ONLY_ACE, 'Inherit-only')]
  [FlagName(INHERITED_ACE, 'Inherited')]
  [FlagName(CRITICAL_ACE_FLAG, 'Critical')]
  [FlagName(SUCCESSFUL_ACCESS_ACE_FLAG, 'Successful Access / Trust-protected Filter')]
  [FlagName(FAILED_ACCESS_ACE_FLAG, 'Falied Access')]
  TAceFlags = type Byte;

  [SDKName('ACE_HEADER')]
  TAceHeader = record
    AceType: TAceType;
    AceFlags: TAceFlags;
    [Bytes] AceSize: Word;
  end;
  PAceHeader = ^TAceHeader;

  [SDKName('ACCESS_ALLOWED_ACE')]
  [SDKName('ACCESS_DENIED_ACE')]
  [SDKName('SYSTEM_AUDIT_ACE')]
  [SDKName('SYSTEM_ALARM_ACE')]
  [SDKName('SYSTEM_RESOURCE_ATTRIBUTE_ACE')]
  [SDKName('SYSTEM_SCOPED_POLICY_ID_ACE')]
  [SDKName('SYSTEM_MANDATORY_LABEL_ACE')]
  [SDKName('SYSTEM_PROCESS_TRUST_LABEL_ACE')]
  [SDKName('SYSTEM_ACCESS_FILTER_ACE')]
  [SDKName('ACCESS_ALLOWED_CALLBACK_ACE')]
  [SDKName('ACCESS_DENIED_CALLBACK_ACE')]
  [SDKName('SYSTEM_AUDIT_CALLBACK_ACE')]
  [SDKName('SYSTEM_ALARM_CALLBACK_ACE')]
  TAce_Internal = record
    Header: TAceHeader;
    Mask: TAccessMask;
  private
    SidStart: Cardinal;
  public
    function Sid: PSid;
  end;
  PAce = ^TAce_Internal;

  [SDKName('ACCESS_ALLOWED_OBJECT_ACE')]
  [SDKName('ACCESS_DENIED_OBJECT_ACE')]
  [SDKName('SYSTEM_AUDIT_OBJECT_ACE')]
  [SDKName('SYSTEM_ALARM_OBJECT_ACE')]
  [SDKName('ACCESS_ALLOWED_CALLBACK_OBJECT_ACE')]
  [SDKName('ACCESS_DENIED_CALLBACK_OBJECT_ACE')]
  [SDKName('SYSTEM_AUDIT_CALLBACK_OBJECT_ACE')]
  [SDKName('SYSTEM_ALARM_CALLBACK_OBJECT_ACE')]
  TObjectAce_Internal = record
    Header: TAceHeader;
    Mask: TAccessMask;
    [Hex] Flags: Cardinal;
    ObjectType: TGuid;
    InheritedObjectType: TGuid;
  private
    SidStart: Cardinal;
  public
    function Sid: PSid;
  end;
  PObjectAce = ^TObjectAce_Internal;

  [SDKName('ACL_INFORMATION_CLASS')]
  [NamingStyle(nsCamelCase, 'Acl'), Range(1)]
  TAclInformationClass = (
    AclReserved = 0,
    AclRevisionInformation = 1, // q: Cardinal (revision)
    AclSizeInformation = 2      // q: TAclSizeInformation
  );

  [SDKName('ACL_SIZE_INFORMATION')]
  TAclSizeInformation = record
    AceCount: Integer;
    [Bytes] AclBytesInUse: Cardinal;
    [Bytes] AclBytesFree: Cardinal;
    function AclBytesTotal: Cardinal;
  end;
  PAclSizeInformation = ^TAclSizeInformation;

  [SDKName('SECURITY_DESCRIPTOR_CONTROL')]
  [FlagName(SE_OWNER_DEFAULTED, 'Owner Defaulted')]
  [FlagName(SE_GROUP_DEFAULTED, 'Group Defaulted')]
  [FlagName(SE_DACL_PRESENT, 'DACL Present')]
  [FlagName(SE_DACL_DEFAULTED, 'DACL Defaulted')]
  [FlagName(SE_SACL_PRESENT, 'SACL Present')]
  [FlagName(SE_SACL_DEFAULTED, 'SACL Defaulted')]
  [FlagName(SE_DACL_UNTRUSTED, 'DACL Untrusted')]
  [FlagName(SE_SERVER_SECURITY, 'Server Security')]
  [FlagName(SE_DACL_AUTO_INHERIT_REQ, 'DACL Auto-inherit Required')]
  [FlagName(SE_SACL_AUTO_INHERIT_REQ, 'SACL Auto-inherit Required')]
  [FlagName(SE_DACL_AUTO_INHERITED, 'DACL Auto-inherited')]
  [FlagName(SE_SACL_AUTO_INHERITED, 'SACL Auto-inherited')]
  [FlagName(SE_DACL_PROTECTED, 'DACL Protected')]
  [FlagName(SE_SACL_PROTECTED, 'SACL Protected')]
  [FlagName(SE_RM_CONTROL_VALID, 'RM Control Valid')]
  [FlagName(SE_SELF_RELATIVE, 'Self-relative')]
  TSecurityDescriptorControl = type Word;
  PSecurityDescriptorControl = ^TSecurityDescriptorControl;

  [SDKName('SECURITY_DESCRIPTOR')]
  TSecurityDescriptor = record
    Revision: Byte;
    Sbz1: Byte;
  case Control: TSecurityDescriptorControl of
    SE_SELF_RELATIVE: (
      OwnerOffset: Cardinal;
      GroupOffset: Cardinal;
      SaclOffset: Cardinal;
      DaclOffset: Cardinal
    );
    0: (
      Owner: PSid;
      Group: PSid;
      Sacl: PAcl;
      Dacl: PAcl
    );
  end;
  PSecurityDescriptor = ^TSecurityDescriptor;

  [SDKName('SECURITY_IMPERSONATION_LEVEL')]
  [NamingStyle(nsCamelCase, 'Security')]
  TSecurityImpersonationLevel = (
    SecurityAnonymous = 0,
    SecurityIdentification = 1,
    SecurityImpersonation = 2,
    SecurityDelegation = 3
  );

  [SDKName('SECURITY_QUALITY_OF_SERVICE')]
  TSecurityQualityOfService = record
    [Bytes, Unlisted] Length: Cardinal;
    ImpersonationLevel: TSecurityImpersonationLevel;
    ContextTrackingMode: Boolean;
    EffectiveOnly: Boolean;
  end;
  PSecurityQualityOfService = ^TSecurityQualityOfService;

  [SDKName('SECURITY_INFORMATION')]
  [FlagName(OWNER_SECURITY_INFORMATION, 'Owner')]
  [FlagName(GROUP_SECURITY_INFORMATION, 'Group')]
  [FlagName(DACL_SECURITY_INFORMATION, 'DACL')]
  [FlagName(SACL_SECURITY_INFORMATION, 'SACL')]
  [FlagName(LABEL_SECURITY_INFORMATION, 'Label')]
  [FlagName(ATTRIBUTE_SECURITY_INFORMATION, 'Attribute')]
  [FlagName(SCOPE_SECURITY_INFORMATION, 'Scope')]
  [FlagName(PROCESS_TRUST_LABEL_SECURITY_INFORMATION, 'Trust Label')]
  [FlagName(ACCESS_FILTER_SECURITY_INFORMATION, 'Filter')]
  [FlagName(BACKUP_SECURITY_INFORMATION, 'Backup')]
  [FlagName(PROTECTED_DACL_SECURITY_INFORMATION, 'Protected DACL')]
  [FlagName(PROTECTED_SACL_SECURITY_INFORMATION, 'Protected SACL')]
  [FlagName(UNPROTECTED_DACL_SECURITY_INFORMATION, 'Unprotected DACL')]
  [FlagName(UNPROTECTED_SACL_SECURITY_INFORMATION, 'Unprotected SACL')]
  TSecurityInformation = type Cardinal;

  [SDKName('QUOTA_LIMITS')]
  TQuotaLimits = record
    [Bytes] PagedPoolLimit: NativeUInt;
    [Bytes] NonPagedPoolLimit: NativeUInt;
    [Bytes] MinimumWorkingSetSize: NativeUInt;
    [Bytes] MaximumWorkingSetSize: NativeUInt;
    [Bytes] PagefileLimit: NativeUInt;
    TimeLimit: TLargeInteger;
  end;
  PQuotaLimits = ^TQuotaLimits;

  [SDKName('IO_COUNTERS')]
  TIoCounters = record
    ReadOperationCount: UInt64;
    WriteOperationCount: UInt64;
    OtherOperationCount: UInt64;
    [Bytes] ReadTransferCount: UInt64;
    [Bytes] WriteTransferCount: UInt64;
    [Bytes] OtherTransferCount: UInt64;
  end;
  PIoCounters = ^TIoCounters;

  [NamingStyle(nsSnakeCase, 'PF'), Range(0, 35)]
  TProcessorFeature = (
    PF_FLOATING_POINT_PRECISION_ERRATA = 0,
    PF_FLOATING_POINT_EMULATED = 1,
    PF_COMPARE_EXCHANGE_DOUBLE = 2,
    PF_MMX_INSTRUCTIONS_AVAILABLE = 3,
    PF_PPC_MOVEMEM_64BIT_OK = 4,
    PF_ALPHA_BYTE_INSTRUCTIONS = 5,
    PF_XMMI_INSTRUCTIONS_AVAILABLE = 6,
    PF_3DNOW_INSTRUCTIONS_AVAILABLE = 7,
    PF_RDTSC_INSTRUCTION_AVAILABLE = 8,
    PF_PAE_ENABLED = 9,
    PF_XMMI64_INSTRUCTIONS_AVAILABLE = 10,
    PF_SSE_DAZ_MODE_AVAILABLE = 11,
    PF_NX_ENABLED = 12,
    PF_SSE3_INSTRUCTIONS_AVAILABLE = 13,
    PF_COMPARE_EXCHANGE128 = 14,
    PF_COMPARE64_EXCHANGE128 = 15,
    PF_CHANNELS_ENABLED = 16,
    PF_XSAVE_ENABLED = 17,
    PF_ARM_VFP_32_REGISTERS_AVAILABLE = 18,
    PF_ARM_NEON_INSTRUCTIONS_AVAILABLE = 19,
    PF_SECOND_LEVEL_ADDRESS_TRANSLATION = 20,
    PF_VIRT_FIRMWARE_ENABLED = 21,
    PF_RDWRFSGSBASE_AVAILABLE = 22,
    PF_FASTFAIL_AVAILABLE = 23,
    PF_ARM_DIVIDE_INSTRUCTION_AVAILABLE = 24,
    PF_ARM_64BIT_LOADSTORE_ATOMIC = 25,
    PF_ARM_EXTERNAL_CACHE_AVAILABLE = 26,
    PF_ARM_FMAC_INSTRUCTIONS_AVAILABLE = 27,
    PF_RDRAND_INSTRUCTION_AVAILABLE = 28,
    PF_ARM_V8_INSTRUCTIONS_AVAILABLE = 29,
    PF_ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE = 30,
    PF_ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE = 31,
    PF_RDTSCP_INSTRUCTION_AVAILABLE = 32,
    PF_RDPID_INSTRUCTION_AVAILABLE = 33,
    PF_ARM_V81_ATOMIC_INSTRUCTIONS_AVAILABLE = 34,
    PF_MONITORX_INSTRUCTION_AVAILABLE = 35,
    PF_RESERVED36, PF_RESERVED37, PF_RESERVED38, PF_RESERVED39, PF_RESERVED40,
    PF_RESERVED41, PF_RESERVED42, PF_RESERVED43, PF_RESERVED44, PF_RESERVED45,
    PF_RESERVED46, PF_RESERVED47, PF_RESERVED48, PF_RESERVED49, PF_RESERVED50,
    PF_RESERVED51, PF_RESERVED52, PF_RESERVED53, PF_RESERVED54, PF_RESERVED55,
    PF_RESERVED56, PF_RESERVED57, PF_RESERVED58, PF_RESERVED59, PF_RESERVED60,
    PF_RESERVED61, PF_RESERVED62, PF_RESERVED63
  );

  // WDK::wdm.h
  [SDKName('KSYSTEM_TIME')]
  KSystemTime = packed record
  case Boolean of
    True: (
     QuadPart: TLargeInteger
    );
    False: (
      LowPart: Cardinal;
      High1Time: Integer;
      High2Time: Integer;
    );
  end;

  // WDK::ntdef.h
  [SDKName('NT_PRODUCT_TYPE')]
  [NamingStyle(nsCamelCase, 'NtProduct'), Range(1)]
  TNtProductType = (
    NtProductUnknown = 0,
    NtProductWinNT = 1,
    NtProductLanManNT = 2,
    NtProductServer = 3
  );

  // WDK::ntddk.h
  [NamingStyle(nsSnakeCase, 'SYSTEM_CALL')]
  TSystemCall = (
    SYSTEM_CALL_SYSCALL = 0,
    SYSTEM_CALL_INT_2E = 1
  );

  TNtSystemRoot = array [0..259] of WideChar;
  TProcessorFeatures = array [TProcessorFeature] of Boolean;

  // WDK::ntddk.h
  [SDKName('KUSER_SHARED_DATA')]
  KUSER_SHARED_DATA = packed record
    TickCountLowDeprecated: Cardinal;
    [Hex] TickCountMultiplier: Cardinal;
    [volatile] InterruptTime: KSystemTime;
    [volatile] SystemTime: KSystemTime;
    [volatile] TimeZoneBias: KSystemTime;
    [Hex] ImageNumberLow: Word;
    [Hex] ImageNumberHigh: Word;
    NtSystemRoot: TNtSystemRoot;
    MaxStackTraceDepth: Cardinal;
    CryptoExponent: Cardinal;
    TimeZoneID: Cardinal;
    [Bytes] LargePageMinimum: Cardinal;
    AitSamplingValue: Cardinal;
    [Hex] AppCompatFlag: Cardinal;
    RNGSeedVersion: Int64;
    GlobalValidationRunlevel: Cardinal;
    TimeZoneBiasStamp: Integer;
    NtBuildNumber: Cardinal;
    NtProductType: TNtProductType;
    ProductTypeIsValid: Boolean;
    [Unlisted] Reserved0: array [0..0] of Byte;
    [Hex] NativeProcessorArchitecture: Word;
    NtMajorVersion: Cardinal;
    NtMinorVersion: Cardinal;
    ProcessorFeatures: TProcessorFeatures;
    [Unlisted] Reserved1: Cardinal;
    [Unlisted] Reserved3: Cardinal;
    [volatile] TimeSlip: Cardinal;
    AlternativeArchitecture: Cardinal;
    BootID: Cardinal;
    SystemExpirationDate: TLargeInteger;
    [Hex] SuiteMask: Cardinal;
    KdDebuggerEnabled: Boolean;
    [Hex] MitigationPolicies: Byte;
    CyclesPerYield: Word;
    [volatile] ActiveConsoleId: TSessionId;
    [volatile] DismountCount: Cardinal;
    [BooleanKind(bkEnabledDisabled)] ComPlusPackage: LongBool;
    LastSystemRITEventTickCount: Cardinal;
    NumberOfPhysicalPages: Cardinal;
    [BooleanKind(bkYesNo)] SafeBootMode: Boolean;
    [Hex] VirtualizationFlags: Byte;
    [Unlisted] Reserved12: array [0..1] of Byte;
    [Hex] SharedDataFlags: Cardinal; // SHARED_GLOBAL_FLAGS_*
    [Unlisted] DataFlagsPad: array [0..0] of Cardinal;
    TestRetInstruction: Int64;
    QpcFrequency: Int64;
    SystemCall: TSystemCall;
    [Unlisted] SystemCallPad0: Cardinal;
    [Unlisted] SystemCallPad: array [0..1] of Int64;
    [volatile] TickCount: KSystemTime;
    [Unlisted] TickCountPad: array [0..0] of Cardinal;
    [Hex] Cookie: Cardinal;
    [Unlisted] CookiePad: array [0..0] of Cardinal;
    [volatile] ConsoleSessionForegroundProcessID: TProcessId;
    {$IFDEF Win32}[Unlisted] Padding: Cardinal;{$ENDIF}
    TimeUpdateLock: Int64;
    [volatile] BaselineSystemTimeQpc: TULargeInteger;
    [volatile] BaselineInterruptTimeQpc: TULargeInteger;
    [Hex] QpcSystemTimeIncrement: UInt64;
    [Hex] QpcInterruptTimeIncrement: UInt64;
    QpcSystemTimeIncrementShift: Byte;
    QpcInterruptTimeIncrementShift: Byte;
    UnparkedProcessorCount: Word;
    EnclaveFeatureMask: array [0..3] of Cardinal;
    TelemetryCoverageRound: Cardinal;
    UserModeGlobalLogger: array [0..15] of Word;
    [Hex] ImageFileExecutionOptions: Cardinal;
    LangGenerationCount: Cardinal;
    [Unlisted] Reserved4: Int64;
    [volatile] InterruptTimeBias: TULargeInteger;
    [volatile] QpcBias: TULargeInteger;
    ActiveProcessorCount: Cardinal;
    [volatile] ActiveGroupCount: Byte;
    [Unlisted] Reserved9: Byte;
    QpcData: Word;
    TimeZoneBiasEffectiveStart: TLargeInteger;
    TimeZoneBiasEffectiveEnd: TLargeInteger;
    function GetTickCount: Cardinal;
  end;
  PKUSER_SHARED_DATA = ^KUSER_SHARED_DATA;

const
  USER_SHARED_DATA = PKUSER_SHARED_DATA($7ffe0000);

  INVALID_SID_TYPES = [SidTypeUndefined, SidTypeInvalid, SidTypeUnknown];

  // 9156
  SECURITY_NULL_SID_AUTHORITY: TSIDIdentifierAuthority =
    (Value: (0, 0, 0, 0, 0, 0));
  SECURITY_WORLD_SID_AUTHORITY: TSIDIdentifierAuthority =
    (Value: (0, 0, 0, 0, 0, 1));
  SECURITY_LOCAL_SID_AUTHORITY: TSIDIdentifierAuthority =
    (Value: (0, 0, 0, 0, 0, 2));
  SECURITY_CREATOR_SID_AUTHORITY: TSIDIdentifierAuthority =
    (Value: (0, 0, 0, 0, 0, 3));
  SECURITY_NON_UNIQUE_AUTHORITY: TSIDIdentifierAuthority =
    (Value: (0, 0, 0, 0, 0, 4));

  SECURITY_NULL_RID = $00000000;         // NULL SID      S-1-0-0
  SECURITY_WORLD_RID = $00000000;        // Everyone      S-1-1-0
  SECURITY_LOCAL_RID = $00000000;        // LOCAL         S-1-2-0
  SECURITY_LOCAL_LOGON_RID  = $00000001; // CONSOLE LOGON S-1-2-1

  SECURITY_CREATOR_OWNER_RID = $00000000;        // CREATOR OWNER        S-1-3-0
  SECURITY_CREATOR_GROUP_RID = $00000001;        // CREATOR GROUP        S-1-3-1
  SECURITY_CREATOR_OWNER_SERVER_RID = $00000002; // CREATOR OWNER SERVER S-1-3-2
  SECURITY_CREATOR_GROUP_SERVER_RID = $00000003; // CREATOR GROUP SERVER S-1-3-3
  SECURITY_CREATOR_OWNER_RIGHTS_RID = $00000004; // OWNER RIGHTS         S-1-3-4

  SECURITY_NT_AUTHORITY_ID = 5;
  SECURITY_NT_AUTHORITY: TSIDIdentifierAuthority =
    (Value: (0, 0, 0, 0, 0, 5)); // S-1-5

  SECURITY_LOGON_IDS_RID = $00000005;       // S-1-5-5-X-X
  SECURITY_LOGON_IDS_RID_COUNT = 3;
  SECURITY_ANONYMOUS_LOGON_RID = $00000007; // S-1-5-7
  SECURITY_RESTRICTED_CODE_RID = $0000000C; // S-1-5-12
  SECURITY_IUSER_RID           = $00000011; // S-1-5-17
  SECURITY_LOCAL_SYSTEM_RID    = $00000012; // S-1-5-18
  SECURITY_LOCAL_SERVICE_RID   = $00000013; // S-1-5-19
  SECURITY_NETWORK_SERVICE_RID = $00000014; // S-1-5-20
  SECURITY_NT_NON_UNIQUE = $00000015;       // S-1-5-21-X-X-X
  SECURITY_NT_NON_UNIQUE_SUB_AUTH_COUNT = 3;
  SECURITY_BUILTIN_DOMAIN_RID = $00000020;  // S-1-5-32
  SECURITY_WRITE_RESTRICTED_CODE_RID = $00000021; // S-1-5-33

  SECURITY_MIN_BASE_RID = $050; // S-1-5-80
  SECURITY_MAX_BASE_RID = $06F; // S-1-5-111

  SECURITY_INSTALLER_GROUP_CAPABILITY_BASE = $00000020; // Same as BUILTIN
  SECURITY_INSTALLER_GROUP_CAPABILITY_RID_COUNT = 9; // S-1-5-32-[+8 from hash]

  DOMAIN_USER_RID_ADMIN = $000001F4;
  DOMAIN_USER_RID_GUEST = $000001F5;
  DOMAIN_USER_RID_KRBTGT = $000001F6;
  DOMAIN_USER_RID_DEFAULT_ACCOUNT = $000001F7;
  DOMAIN_USER_RID_WDAG_ACCOUNT = $000001F8;

  DOMAIN_GROUP_RID_ADMINS = $00000200;
  DOMAIN_GROUP_RID_USERS = $00000201;
  DOMAIN_GROUP_RID_GUESTS = $00000202;

  DOMAIN_ALIAS_RID_ADMINS = $00000220;
  DOMAIN_ALIAS_RID_USERS = $00000221;
  DOMAIN_ALIAS_RID_GUESTS = $00000222;
  DOMAIN_ALIAS_RID_POWER_USERS = $00000223;

  SECURITY_APP_PACKAGE_AUTHORITY: TSIDIdentifierAuthority =
    (Value: (0, 0, 0, 0, 0, 15)); // S-1-15

  SECURITY_CAPABILITY_BASE_RID = $00000003;
  SECURITY_CAPABILITY_APP_RID = $00000400;
  SECURITY_INSTALLER_CAPABILITY_RID_COUNT = 10; // S-1-15-3-1024-[+8 from hash]

  SECURITY_APP_PACKAGE_BASE_RID = $00000002;
  SECURITY_BUILTIN_APP_PACKAGE_RID_COUNT = 2;

  SECURITY_APP_PACKAGE_RID_COUNT = 8;
  SECURITY_PARENT_PACKAGE_RID_COUNT = SECURITY_APP_PACKAGE_RID_COUNT;
  SECURITY_CHILD_PACKAGE_RID_COUNT = 12;

  SECURITY_BUILTIN_PACKAGE_ANY_PACKAGE = $00000001;            // S-1-15-2-1
  SECURITY_BUILTIN_PACKAGE_ANY_RESTRICTED_PACKAGE = $00000002; // S-1-15-2-2

  SECURITY_MANDATORY_LABEL_AUTHORITY_ID = 16;
  SECURITY_MANDATORY_LABEL_AUTHORITY: TSIDIdentifierAuthority =
    (Value: (0, 0, 0, 0, 0, 16)); // S-1-16

  // Integrity levels, S-1-16-X
  SECURITY_MANDATORY_UNTRUSTED_RID = $0000;
  SECURITY_MANDATORY_LOW_RID = $1000;
  SECURITY_MANDATORY_MEDIUM_RID = $2000;
  SECURITY_MANDATORY_MEDIUM_PLUS_RID = SECURITY_MANDATORY_MEDIUM_RID + $0100;
  SECURITY_MANDATORY_HIGH_RID = $3000;
  SECURITY_MANDATORY_SYSTEM_RID = $4000;
  SECURITY_MANDATORY_PROTECTED_PROCESS_RID = $5000;

  // Known logon sessions
  SYSTEM_LUID = $3e7;
  ANONYMOUS_LOGON_LUID = $3e6;
  LOCALSERVICE_LUID = $3e5;
  NETWORKSERVICE_LUID = $3e4;
  IUSER_LUID = $3e3;

  NonObjectAces: TAceTypeSet = [ACCESS_ALLOWED_ACE_TYPE..SYSTEM_ALARM_ACE_TYPE,
    ACCESS_ALLOWED_CALLBACK_ACE_TYPE..ACCESS_DENIED_CALLBACK_ACE_TYPE,
    SYSTEM_AUDIT_CALLBACK_ACE_TYPE..SYSTEM_ALARM_CALLBACK_ACE_TYPE,
    SYSTEM_MANDATORY_LABEL_ACE_TYPE..SYSTEM_ACCESS_FILTER_ACE_TYPE
  ];

  ObjectAces: TAceTypeSet = [ACCESS_ALLOWED_OBJECT_ACE_TYPE..
    SYSTEM_ALARM_OBJECT_ACE_TYPE, ACCESS_ALLOWED_CALLBACK_OBJECT_ACE_TYPE..
    ACCESS_DENIED_CALLBACK_OBJECT_ACE_TYPE,
    SYSTEM_AUDIT_CALLBACK_OBJECT_ACE_TYPE..SYSTEM_ALARM_CALLBACK_OBJECT_ACE_TYPE
  ];

  AccessAllowedAces: TAceTypeSet = [ACCESS_ALLOWED_ACE_TYPE,
    ACCESS_ALLOWED_COMPOUND_ACE_TYPE, ACCESS_ALLOWED_OBJECT_ACE_TYPE,
    ACCESS_ALLOWED_CALLBACK_ACE_TYPE, ACCESS_ALLOWED_CALLBACK_OBJECT_ACE_TYPE];

  AccessDeniedAces: TAceTypeSet = [ACCESS_DENIED_ACE_TYPE,
    ACCESS_DENIED_OBJECT_ACE_TYPE, ACCESS_DENIED_CALLBACK_ACE_TYPE,
    ACCESS_DENIED_CALLBACK_OBJECT_ACE_TYPE];

  MILLISEC_PER_DAY = 86400000;

  DAYS_FROM_1601 = 109205; // difference with Delphi's zero time in days
  NATIVE_TIME_DAY = 864000000000; // 100ns in 1 day
  NATIVE_TIME_HOUR = 36000000000; // 100ns in 1 hour
  NATIVE_TIME_MINUTE = 600000000; // 100ns in 1 minute
  NATIVE_TIME_SECOND =  10000000; // 100ns in 1 sec
  NATIVE_TIME_MILLISEC =   10000; // 100ns in 1 millisec

  INFINITE_FUTURE = TLargeInteger(-1);

function TimeoutToLargeInteger(
  const [ref] Timeout: Int64
): PLargeInteger; inline;

function DateTimeToLargeInteger(DateTime: TDateTime): TLargeInteger;
function LargeIntegerToDateTime(QuadPart: TLargeInteger): TDateTime;

// Expected access masks when accessing security
function SecurityReadAccess(Info: TSecurityInformation): TAccessMask;
function SecurityWriteAccess(Info: TSecurityInformation): TAccessMask;

implementation

{ TSidIdentifierAuthority }

class operator TSidIdentifierAuthority.Implicit(
  const Source: TSidIdentifierAuthority): UInt64;
begin
  Result := (UInt64(Source.Value[5]) shl  0) or
            (UInt64(Source.Value[4]) shl  8) or
            (UInt64(Source.Value[3]) shl 16) or
            (UInt64(Source.Value[2]) shl 24) or
            (UInt64(Source.Value[1]) shl 32) or
            (UInt64(Source.Value[0]) shl 40);
end;

class operator TSidIdentifierAuthority.Implicit(
  const Source: UInt64): TSidIdentifierAuthority;
begin
  Result.Value[0] := Byte(Source shr 40);
  Result.Value[1] := Byte(Source shr 32);
  Result.Value[2] := Byte(Source shr 24);
  Result.Value[3] := Byte(Source shr 16);
  Result.Value[4] := Byte(Source shr 8);
  Result.Value[5] := Byte(Source shr 0);
end;

{ TAce_Internal }

function TAce_Internal.Sid;
begin
  Pointer(Result) := @Self.SidStart;
end;

{ TObjectAce_Internal }

function TObjectAce_Internal.Sid;
begin
  Pointer(Result) := @Self.SidStart;
end;

{ TAclSizeInformation }

function TAclSizeInformation.AclBytesTotal;
begin
  Result := AclBytesInUse + AclBytesFree;
end;

{ Conversion functions }

function TimeoutToLargeInteger;
begin
  if Timeout = NT_INFINITE then
    Result := nil
  else
    Result := PLargeInteger(@Timeout);
end;

function DateTimeToLargeInteger;
begin
  Result := Trunc(NATIVE_TIME_DAY * (DAYS_FROM_1601 + DateTime))
    + USER_SHARED_DATA.TimeZoneBias.QuadPart;
end;

function LargeIntegerToDateTime;
begin
  {$Q-}Result := (QuadPart - USER_SHARED_DATA.TimeZoneBias.QuadPart) /
    NATIVE_TIME_DAY - DAYS_FROM_1601;{$Q+}
end;

function SecurityReadAccess;
const
  REQUIRE_READ_CONTROL = OWNER_SECURITY_INFORMATION or
    GROUP_SECURITY_INFORMATION or DACL_SECURITY_INFORMATION or
    LABEL_SECURITY_INFORMATION or ATTRIBUTE_SECURITY_INFORMATION or
    SCOPE_SECURITY_INFORMATION or BACKUP_SECURITY_INFORMATION;

  REQUIRE_SYSTEM_SECURITY = SACL_SECURITY_INFORMATION or
    BACKUP_SECURITY_INFORMATION;
begin
  Result := 0;

  if Info and REQUIRE_READ_CONTROL <> 0 then
    Result := Result or READ_CONTROL;

  if Info and REQUIRE_SYSTEM_SECURITY <> 0 then
    Result := Result or ACCESS_SYSTEM_SECURITY;
end;

function SecurityWriteAccess;
const
  REQUIRE_WRITE_DAC = DACL_SECURITY_INFORMATION or
    ATTRIBUTE_SECURITY_INFORMATION or BACKUP_SECURITY_INFORMATION or
    PROTECTED_DACL_SECURITY_INFORMATION or UNPROTECTED_DACL_SECURITY_INFORMATION;

  REQUIRE_WRITE_OWNER = OWNER_SECURITY_INFORMATION or GROUP_SECURITY_INFORMATION
    or LABEL_SECURITY_INFORMATION or BACKUP_SECURITY_INFORMATION;

  REQUIRE_SYSTEM_SECURITY = SACL_SECURITY_INFORMATION or
    SCOPE_SECURITY_INFORMATION or BACKUP_SECURITY_INFORMATION or
    PROTECTED_SACL_SECURITY_INFORMATION or UNPROTECTED_SACL_SECURITY_INFORMATION;
begin
  Result := 0;

  if Info and REQUIRE_WRITE_DAC <> 0 then
    Result := Result or WRITE_DAC;

  if Info and REQUIRE_WRITE_OWNER <> 0 then
    Result := Result or WRITE_OWNER;

  if Info and REQUIRE_SYSTEM_SECURITY <> 0 then
    Result := Result or ACCESS_SYSTEM_SECURITY;
end;

{ KUSER_SHARED_DATA }

function KUSER_SHARED_DATA.GetTickCount;
begin
  {$Q-}{$R-}
  Result := UInt64(TickCount.LowPart) * TickCountMultiplier shr 24;
  {$Q+}{$R+}
end;

end.