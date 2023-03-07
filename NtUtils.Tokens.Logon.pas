unit NtUtils.Tokens.Logon;

{
  The module introduces functions for logging users into the system via a
  normal and Services-for-Users logon.
}

interface

uses
  Ntapi.WinNt, Ntapi.WinBase, Ntapi.NtSecApi, Ntapi.ntseapi, NtUtils,
  NtUtils.Objects, DelphiApi.Reflection;

type
  TLogonInfoFields = set of (
    liToken,              // All
    liLogonId,            // All
    liQuotas,             // All
    liLogonCount,         // Interactive
    liBadPasswordCount,   // Interactive
    liLogonTime,          // Interactive
    liLogoffTime,         // Interactive, Lm20
    liKickOffTime,        // Interactive, Lm20
    liPasswordLastSet,    // Interactive
    liPasswordCanChange,  // Interactive
    liPasswordMustChange, // Interactive
    liLogonScript,        // Interactive
    liHomeDirectory,      // Interactive
    liHomeDirectoryDrive, // Interactive
    liFullName,           // Interactive
    liProfilePath,        // Interactive
    liLogonServer,        // Interactive, Lm20
    liUserFlags,          // Interactive, Lm20
    liUserSessionKey,     // Lm20
    liLogonDomainName,    // Lm20
    liLanmanSessionKey,   // Lm20
    liUserParameters      // Lm20
  );

  TLogonInfo = record
    ValidFields: TLogonInfoFields;
    hxToken: IHandle;
    LogonId: TLogonId;
    Quotas: TQuotaLimits;
    LogonCount: Word;
    BadPasswordCount: Word;
    LogonTime: TLargeInteger;
    LogoffTime: TLargeInteger;
    KickOffTime: TLargeInteger;
    PasswordLastSet: TLargeInteger;
    PasswordCanChange: TLargeInteger;
    PasswordMustChange: TLargeInteger;
    LogonScript: String;
    HomeDirectory: String;
    HomeDirectoryDrive: String;
    FullName: String;
    ProfilePath: String;
    LogonServer: String;
    UserFlags: TLogonFlags;
    UserSessionKey: TGuid;
    LogonDomainName: String;
    [Hex] LanmanSessionKey: UInt64;
    UserParameters: String;
  end;

  TLogonCredentials = record
    Domain: String;
    Username: String;
    Password: String;
    S4UFlags: TS4ULogonFlags;
  end;

// A low-level wrapper for LsaLogonUser
[RequiredPrivilege(SE_TCB_PRIVILEGE, rpSometimes)]
function LsaxLogonUserInternal(
  out Info: TLogonInfo;
  const Buffer: IMemory;
  const LogonType: TSecurityLogonType;
  const TokenSource: TTokenSource;
  [opt] const AdditionalGroups: TArray<TGroup> = nil;
  const PackageName: AnsiString = NEGOSSP_NAME_A
): TNtxStatus;

// Logon a user
[RequiredPrivilege(SE_TCB_PRIVILEGE, rpSometimes)]
function LsaxLogonUser(
  out Info: TLogonInfo;
  MessageType: TLogonSubmitType;
  LogonType: TSecurityLogonType;
  const Credentials: TLogonCredentials;
  const TokenSource: TTokenSource;
  [opt] const AdditionalGroups: TArray<TGroup> = nil;
  const PackageName: AnsiString = NEGOSSP_NAME_A
): TNtxStatus;

implementation

uses
  Ntapi.ntdef, Ntapi.ntstatus, NtUtils.Processes.Info, NtUtils.Tokens.Misc,
  DelphiUtils.AutoObjects, NtUtils.Lsa, NtUtils.Security.Sid;

{$BOOLEVAL OFF}
{$IFOPT R+}{$DEFINE R+}{$ENDIF}
{$IFOPT Q+}{$DEFINE Q+}{$ENDIF}

function LsaxDelayFreeReturnBuffer(
  [in] Buffer: Pointer
): IAutoReleasable;
begin
  Result := Auto.Delay(
    procedure
    begin
      LsaFreeReturnBuffer(Buffer);
    end
  );
end;

function LsaxCaptureLogonProfile(
  var Info: TLogonInfo;
  [in, ReadsFrom] Profile: Pointer;
  [in, NumberOfBytes] ProfileSize: Cardinal
): TNtxStatus;
var
  ProfileInteractive: PInteractiveLogonProfile absolute Profile;
  ProfileLm20: PLm20LogonProfile absolute Profile;
begin
  Result.Location := 'LsaxCaptureLogonProfile';

  if ProfileSize < SizeOf(TLogonProfileBufferType) then
  begin
    Result.Status := STATUS_INVALID_BUFFER_SIZE;
    Exit;
  end;

  case TLogonProfileBufferType(Profile^) of
    TLogonProfileBufferType.InteractiveProfile:
    begin
      if ProfileSize < SizeOf(TInteractiveLogonProfile) then
      begin
        Result.Status := STATUS_INVALID_BUFFER_SIZE;
        Exit;
      end;

      Info.ValidFields := Info.ValidFields + [liLogonCount..liUserFlags];
      Info.LogonCount := ProfileInteractive.LogonCount;
      Info.BadPasswordCount := ProfileInteractive.BadPasswordCount;
      Info.LogonTime := ProfileInteractive.LogonTime;
      Info.LogoffTime := ProfileInteractive.LogoffTime;
      Info.KickOffTime := ProfileInteractive.KickOffTime;
      Info.PasswordLastSet := ProfileInteractive.PasswordLastSet;
      Info.PasswordCanChange := ProfileInteractive.PasswordCanChange;
      Info.PasswordMustChange := ProfileInteractive.PasswordMustChange;
      Info.LogonScript := ProfileInteractive.LogonScript.ToString;
      Info.HomeDirectory := ProfileInteractive.HomeDirectory.ToString;
      Info.HomeDirectoryDrive := ProfileInteractive.HomeDirectoryDrive.ToString;
      Info.FullName := ProfileInteractive.FullName.ToString;
      Info.ProfilePath := ProfileInteractive.ProfilePath.ToString;
      Info.LogonServer := ProfileInteractive.LogonServer.ToString;
      Info.UserFlags := ProfileInteractive.UserFlags;
    end;

    TLogonProfileBufferType.Lm20LogonProfile:
    begin
      if ProfileSize < SizeOf(TLm20LogonProfile) then
      begin
        Result.Status := STATUS_INVALID_BUFFER_SIZE;
        Exit;
      end;

      Info.ValidFields := Info.ValidFields + [liLogoffTime, liKickOffTime,
        liLogonServer, liUserFlags, liUserSessionKey..liUserParameters];
      Info.LogoffTime := ProfileLm20.LogoffTime;
      Info.KickOffTime := ProfileLm20.KickOffTime;
      Info.LogonServer := ProfileLm20.LogonServer.ToString;
      Info.UserFlags := ProfileLm20.UserFlags;
      Info.UserSessionKey := ProfileLm20.UserSessionKey;
      Info.LogonDomainName := ProfileLm20.LogonDomainName.ToString;
      Info.LanmanSessionKey := ProfileLm20.LanmanSessionKey;
      Info.UserParameters := ProfileLm20.UserParameters.ToString;
    end
  else
    Result.Status := STATUS_NOT_SUPPORTED;
    Exit;
  end;

  Result.Status := STATUS_SUCCESS;
end;

function LsaxLogonUserInternal;
var
  hToken: THandle;
  LsaHandle: ILsaHandle;
  AuthPkg: Cardinal;
  GroupArray: IMemory<PTokenGroups>;
  GroupArrayData: Pointer;
  ProfileBuffer: Pointer;
  ProfileBufferLength: Cardinal;
  ProfileBufferDeallocator: IAutoReleasable;
  SubStatus: NTSTATUS;
begin
  Info := Default(TLogonInfo);
  GroupArrayData := nil;

  // Connect to LSA
  Result := LsaxConnectUntrusted(LsaHandle);

  if not Result.IsSuccess then
    Exit;

  // Lookup the Negotiate package
  Result := LsaxLookupAuthPackage(AuthPkg, PackageName, LsaHandle);

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'LsaLogonUser';
  Result.LastCall.UsesInfoClass(TLogonSubmitType(Buffer.Data^), icPerform);

  if Length(AdditionalGroups) > 0 then
  begin
    // Note: The function requires SeTcbPrivilege when adding groups but
    // returns ERROR_ACCESS_DENIED in place of ERROR_PRIVILEGE_NOT_HELD,
    // which is confusing.
    Result.LastCall.ExpectedPrivilege := SE_TCB_PRIVILEGE;

    GroupArray := NtxpAllocGroups2(AdditionalGroups);
    GroupArrayData := GroupArray.Data;
  end;

  SubStatus := STATUS_SUCCESS;

  // Perform the logon
  Result.Status := LsaLogonUser(LsaHandle.Handle, TLsaAnsiString.From('S4U'),
    LogonType, AuthPkg, Buffer.Data, Buffer.Size, GroupArrayData, TokenSource,
    ProfileBuffer, ProfileBufferLength, Info.LogonId, hToken, Info.Quotas,
    SubStatus);

  if not Result.IsSuccess then
  begin
    // Prefer more detailed errors
    if not NT_SUCCESS(SubStatus) then
      Result.Status := SubStatus;

    Exit;
  end;

  Info.ValidFields := [liToken, liLogonId, liQuotas];
  Info.hxToken := Auto.CaptureHandle(hToken);

  if Assigned(ProfileBuffer) then
  begin
    ProfileBufferDeallocator := LsaxDelayFreeReturnBuffer(ProfileBuffer);
    LsaxCaptureLogonProfile(Info, ProfileBuffer, ProfileBufferLength);
  end;
end;

function LsaxMakeInteractiveBuffer(
  MessageType: TLogonSubmitType;
  const Credentials: TLogonCredentials
): IMemory<PInteractiveLogon>;
var
  Cursor: Pointer;
begin
  IMemory(Result) := Auto.AllocateDynamic(
    SizeOf(TInteractiveLogon) +
    StringSizeZero(Credentials.Username) +
    StringSizeZero(Credentials.Domain) +
    StringSizeZero(Credentials.Password)
  );

  Result.Data.MessageType := MessageType;
  Cursor := Result.Offset(SizeOf(TInteractiveLogon));

  MarshalUnicodeString(Credentials.Domain, Result.Data.LogonDomainName, Cursor);
  Inc(PByte(Cursor), Result.Data.LogonDomainName.MaximumLength);

  MarshalUnicodeString(Credentials.Username, Result.Data.UserName, Cursor);
  Inc(PByte(Cursor), Result.Data.UserName.MaximumLength);

  MarshalUnicodeString(Credentials.Password, Result.Data.Password, Cursor);
  Inc(PByte(Cursor), Result.Data.Password.MaximumLength);
end;

function LsaxMakeS4UBuffer(
  MessageType: TLogonSubmitType;
  const Credentials: TLogonCredentials
): IMemory<PS4ULogon>;
var
  Cursor: Pointer;
begin
  IMemory(Result) := Auto.AllocateDynamic(
    SizeOf(TS4ULogon) +
    StringSizeZero(Credentials.Username) +
    StringSizeZero(Credentials.Domain)
  );

  Result.Data.MessageType := MessageType;
  Result.Data.Flags := Credentials.S4UFlags;
  Cursor := Result.Offset(SizeOf(TS4ULogon));

  MarshalUnicodeString(Credentials.Username, Result.Data.UserPrincipalName, Cursor);
  Inc(PByte(Cursor), Result.Data.UserPrincipalName.MaximumLength);

  MarshalUnicodeString(Credentials.Domain, Result.Data.DomainName, Cursor);
  Inc(PByte(Cursor), Result.Data.DomainName.MaximumLength);
end;

function LsaxLogonUser;
var
  Buffer: IMemory;
begin
  case MessageType of
    TLogonSubmitType.InteractiveLogon, TLogonSubmitType.VirtualLogon,
    TLogonSubmitType.NoElevationLogon:
      Buffer := IMemory(LsaxMakeInteractiveBuffer(MessageType, Credentials));

    TLogonSubmitType.S4ULogon:
      Buffer := IMemory(LsaxMakeS4UBuffer(MessageType, Credentials));
  else
    Result.Location := 'LsaxLogonUser';
    Result.Status := STATUS_NOT_IMPLEMENTED;
    Exit;
  end;

  Result := LsaxLogonUserInternal(Info, Buffer, LogonType, TokenSource,
    AdditionalGroups, PackageName);
end;

end.
