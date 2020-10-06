unit Winapi.WinError;

{$MINENUMSIZE 4}

interface

const
  HRESULT_SEVERITY_MASK = $80000000;
  FACILITY_NT_BIT =       $10000000;
  HRESULT_FACILITY_MASK = $07FF0000;
  WIN32_CODE_MASK =       $0000FFFF;

  FACILITY_SHIFT = 16;
  FACILITY_WIN32 = 7;
  FACILITY_WIN32_BITS = FACILITY_WIN32 shl FACILITY_SHIFT;
  WIN32_HRESULT_BITS = HRESULT_SEVERITY_MASK or FACILITY_WIN32_BITS;

  ERROR_SUCCESS = 0;
  ERROR_PATH_NOT_FOUND = 3;
  ERROR_ACCESS_DENIED = 5;
  ERROR_BAD_LENGTH = 24;
  ERROR_INVALID_PARAMETER = 87;
  ERROR_CALL_NOT_IMPLEMENTED = 120;
  ERROR_INSUFFICIENT_BUFFER = 122;
  ERROR_ALREADY_EXISTS = 183;
  ERROR_MORE_DATA = 234;
  WAIT_TIMEOUT = 258;
  ERROR_MR_MID_NOT_FOUND = 317;
  ERROR_CANT_ENABLE_DENY_ONLY = 629;
  ERROR_NO_TOKEN = 1008;
  ERROR_IMPLEMENTATION_LIMIT = 1292;
  ERROR_NOT_ALL_ASSIGNED = 1300;
  ERROR_INVALID_OWNER = 1307;
  ERROR_INVALID_PRIMARY_GROUP = 1308;
  ERROR_CANT_DISABLE_MANDATORY = 1310;
  ERROR_PRIVILEGE_NOT_HELD = 1314;
  ERROR_BAD_IMPERSONATION_LEVEL = 1346;

  S_OK    = $00000000;
  S_FALSE = $00000001;
  E_NOTIMPL = HRESULT($80004001);
  E_NOINTERFACE = HRESULT($80004002);
  E_UNEXPECTED = HRESULT($8000FFFF);

  RPC_E_CHANGED_MODE = HRESULT($80010106);
  DISP_E_EXCEPTION = HRESULT($80020009);

// Get an HRESULT code from a Win32 error;
function HResultFromWin32(Win32Error: Cardinal): HRESULT; inline;

implementation

function HResultFromWin32(Win32Error: Cardinal): HRESULT;
begin
  if Integer(Win32Error) <= 0 then
    Result := Win32Error
  else
    Result := (Win32Error and WIN32_CODE_MASK) or WIN32_HRESULT_BITS;
end;

end.
