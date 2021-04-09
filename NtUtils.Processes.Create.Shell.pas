unit NtUtils.Processes.Create.Shell;

{
  The module provides support for process creation via Shell API
}

interface

uses
  NtUtils, NtUtils.Processes.Create;

// Create a new process via ShellExecuteExW
function ShlxExecute(
  const Options: TCreateProcessOptions;
  out Info: TProcessInfo
): TNtxStatus;

implementation

uses
  Winapi.Shell, Winapi.WinUser, NtUtils.Objects, DelphiUtils.AutoObject;

function ShlxExecute;
var
  ExecInfo: TShellExecuteInfoW;
  RunAsInvoker: IAutoReleasable;
begin
  ExecInfo := Default(TShellExecuteInfoW);

  ExecInfo.cbSize := SizeOf(TShellExecuteInfoW);
  ExecInfo.Mask := SEE_MASK_NOASYNC or SEE_MASK_UNICODE or
    SEE_MASK_NOCLOSEPROCESS or SEE_MASK_FLAG_NO_UI;

  ExecInfo.FileName := PWideChar(Options.Application);
  ExecInfo.Parameters := PWideChar(Options.Parameters);
  ExecInfo.Directory := PWideChar(Options.CurrentDirectory);

  // Always set window mode to something
  if BitTest(Options.Flags and PROCESS_OPTION_USE_WINDOW_MODE) then
    ExecInfo.nShow := Integer(Options.WindowMode)
  else
    ExecInfo.nShow := Integer(SW_SHOW_DEFAULT);

  // SEE_MASK_NO_CONSOLE is opposite to CREATE_NEW_CONSOLE
  if not BitTest(Options.Flags and PROCESS_OPTION_NEW_CONSOLE) then
    ExecInfo.Mask := ExecInfo.Mask or SEE_MASK_NO_CONSOLE;

  // Request elevation
  if BitTest(Options.Flags and PROCESS_OPTION_REQUIRE_ELEVATION) then
    ExecInfo.Verb := 'runas';

  // Allow running as invoker
  Result := RtlxApplyCompatLayer(Options, RunAsInvoker);

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'ShellExecuteExW';
  Result.Win32Result := ShellExecuteExW(ExecInfo);

  // We only conditionally get a handle to the process.
  if Result.IsSuccess then
  begin
    Info := Default(TProcessInfo);

    if ExecInfo.hProcess <> 0 then
      Info.hxProcess := TAutoHandle.Capture(ExecInfo.hProcess);
  end;
end;

end.
