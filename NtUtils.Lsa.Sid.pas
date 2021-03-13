unit NtUtils.Lsa.Sid;

{
  The module allows conversion between account names and SIDs and its management
}

interface

uses
  Winapi.WinNt, NtUtils, NtUtils.Lsa;

type
  TTranslatedName = record
    DomainName, UserName: String;
    SidType: TSidNameUse;
    function FullName: String;
  end;

// Convert a SID to a account name
function LsaxLookupSid(
  Sid: PSid;
  out Name: TTranslatedName;
  hxPolicy: ILsaHandle = nil
): TNtxStatus;

// Convert multiple SIDs to a account names
function LsaxLookupSids(
  Sids: TArray<PSid>;
  out Names: TArray<TTranslatedName>;
  hxPolicy: ILsaHandle = nil
): TNtxStatus;

// Convert SID to full account name or at least to SDDL
function LsaxSidToString(
  Sid: PSid
): String;

// Convert an account name to a SID
function LsaxLookupName(
  AccountName: String;
  out Sid: ISid;  hxPolicy:
  ILsaHandle = nil
): TNtxStatus;

// Convert an account name or an SDDL string to a SID
function LsaxLookupNameOrSddl(
  AccountOrSddl: String;
  out Sid: ISid;
  hxPolicy: ILsaHandle = nil
): TNtxStatus;

// Get current the name and the domain of the current user
function LsaxGetUserName(out Domain, UserName: String): TNtxStatus;

// Get the full name of the current user
function LsaxGetFullUserName(out FullName: String): TNtxStatus;

// Assign a name to an SID
function LsaxAddSidNameMapping(
  Domain: String;
  User: String;
  Sid: PSid
): TNtxStatus;

// Revoke a name from an SID
function LsaxRemoveSidNameMapping(
  Domain: String;
  User: String
): TNtxStatus;

implementation

uses
  Winapi.ntlsa, Winapi.NtSecApi, Ntapi.ntstatus, Ntapi.ntseapi,
  NtUtils.SysUtils, NtUtils.Security.Sid;

{ TTranslatedName }

function TTranslatedName.FullName;
begin
  if SidType = SidTypeDomain then
    Result := DomainName
  else if (UserName <> '') and (DomainName <> '') then
    Result := DomainName + '\' + UserName
  else if (UserName <> '') then
    Result := UserName
  else
    Result := '';
end;

{ Functions }

function LsaxLookupSid;
var
  Sids: TArray<PSid>;
  Names: TArray<TTranslatedName>;
begin
  SetLength(Sids, 1);
  Sids[0] := Sid;

  Result := LsaxLookupSids(Sids, Names, hxPolicy);

  if Result.IsSuccess then
    Name := Names[0];
end;

function LsaxLookupSids;
var
  BufferDomains: PLsaReferencedDomainList;
  BufferNames: PLsaTranslatedNameArray;
  i: Integer;
begin
  Result := LsaxpEnsureConnected(hxPolicy, POLICY_LOOKUP_NAMES);

  if not Result.IsSuccess then
    Exit;

  // Request translation for all SIDs at once
  Result.Location := 'LsaLookupSids';
  Result.Status := LsaLookupSids(hxPolicy.Handle, Length(Sids), Sids,
    BufferDomains, BufferNames);

  // Even without mapping we get to know SID types
  if Result.Status = STATUS_NONE_MAPPED then
    Result.Status := STATUS_SOME_NOT_MAPPED;

  if not Result.IsSuccess then
    Exit;

  SetLength(Names, Length(SIDs));

  for i := 0 to High(Sids) do
  begin
    Names[i].SidType := BufferNames{$R-}[i]{$R+}.Use;

    // Note: for some SID types LsaLookupSids might return SID's SDDL
    // representation in the Name field. In rare cases it might be empty.
    // According to [MS-LSAT] the name is valid unless the SID type is
    // SidTypeUnknown

    Names[i].UserName := BufferNames{$R-}[i]{$R+}.Name.ToString;

    // Negative DomainIndex means the SID does not reference a domain
    if (BufferNames{$R-}[i]{$R+}.DomainIndex >= 0) and
      (BufferNames{$R-}[i]{$R+}.DomainIndex < BufferDomains.Entries) then
      Names[i].DomainName := BufferDomains.Domains[
        BufferNames{$R-}[i]{$R+}.DomainIndex].Name.ToString
    else
      Names[i].DomainName := '';
  end;

  LsaFreeMemory(BufferDomains);
  LsaFreeMemory(BufferNames);
end;

function LsaxSidToString;
var
  AccountName: TTranslatedName;
begin
  if LsaxLookupSid(Sid, AccountName).IsSuccess and not (AccountName.SidType in
    [SidTypeUndefined, SidTypeInvalid, SidTypeUnknown]) then
    Result := AccountName.FullName
  else
    Result := RtlxSidToString(Sid);
end;

function LsaxLookupName;
var
  BufferDomain: PLsaReferencedDomainList;
  BufferTranslatedSid: PLsaTranslatedSid2;
  NeedsFreeMemory: Boolean;
begin
  Result := LsaxpEnsureConnected(hxPolicy, POLICY_LOOKUP_NAMES);

  if not Result.IsSuccess then
    Exit;

  // Request translation of one name
  Result.Location := 'LsaLookupNames2';
  Result.Status := LsaLookupNames2(hxPolicy.Handle, 0, 1,
    TLsaUnicodeString.From(AccountName), BufferDomain, BufferTranslatedSid);

  // LsaLookupNames2 allocates memory even on some errors
  NeedsFreeMemory := Result.IsSuccess or (Result.Status = STATUS_NONE_MAPPED);

  if Result.IsSuccess then
    Result := RtlxCopySid(BufferTranslatedSid.Sid, Sid);

  if NeedsFreeMemory then
  begin
    LsaFreeMemory(BufferDomain);
    LsaFreeMemory(BufferTranslatedSid);
  end;
end;

function LsaxLookupNameOrSddl;
var
  Status: TNtxStatus;
begin
  // Since someone might create an account which name is a valid SDDL string,
  // lookup the account name first. Parse it as SDDL only if this lookup failed.
  Result := LsaxLookupName(AccountOrSddl, Sid, hxPolicy);

  if Result.IsSuccess then
    Exit;

  // The string can start with "S-1-" and represent an arbitrary SID or can be
  // one of ~40 double-letter abbreviations. See [MS-DTYP] for SDDL definition.
  if (Length(AccountOrSddl) = 2) or RtlxPrefixString('S-1-', AccountOrSddl,
    True) then
  begin
    Status := RtlxStringToSid(AccountOrSddl, Sid);

    if Status.IsSuccess then
      Result := Status;
  end;
end;

function LsaxGetUserName;
var
  BufferUser, BufferDomain: PLsaUnicodeString;
begin
  Result.Location := 'LsaGetUserName';
  Result.Status := LsaGetUserName(BufferUser, BufferDomain);

  if Result.IsSuccess then
  begin
    Domain := BufferDomain.ToString;
    UserName := BufferUser.ToString;

    LsaFreeMemory(BufferUser);
    LsaFreeMemory(BufferDomain);
  end;
end;

function LsaxGetFullUserName;
var
  Domain, UserName: String;
begin
  Result := LsaxGetUserName(Domain, UserName);

  if not Result.IsSuccess then
    Exit;

  if (Domain <> '') and (UserName <> '') then
    FullName := Domain + '\' + UserName
  else if Domain <> '' then
    FullName := Domain
  else if UserName <> '' then
    FullName := UserName
  else
  begin
    Result.Location := 'LsaxGetUserName';
    Result.Status := STATUS_UNSUCCESSFUL;
  end;
end;

function LsaxManageSidNameMapping(
  OperationType: TLsaSidNameMappingOperationType;
  Input: TLsaSidNameMappingOperation
): TNtxStatus;
var
  pOutput: PLsaSidNameMappingOperationGenericOutput;
begin
  pOutput := nil;

  Result.Location := 'LsaManageSidNameMapping';
  Result.LastCall.ExpectedPrivilege := SE_TCB_PRIVILEGE;

  Result.Status := LsaManageSidNameMapping(OperationType, Input, pOutput);

  // The function uses a custom way to report some errors
  if not Result.IsSuccess and Assigned(pOutput) then
    case pOutput.ErrorCode of
      LsaSidNameMappingOperation_NameCollision,
      LsaSidNameMappingOperation_SidCollision:
        Result.Status := STATUS_OBJECT_NAME_COLLISION;

      LsaSidNameMappingOperation_DomainNotFound:
        Result.Status := STATUS_NO_SUCH_DOMAIN;

      LsaSidNameMappingOperation_DomainSidPrefixMismatch:
        Result.Status := STATUS_INVALID_SID;

      LsaSidNameMappingOperation_MappingNotFound:
        Result.Status := STATUS_NOT_FOUND;
    end;

  if Assigned(pOutput) then
    LsaFreeMemory(pOutput);
end;

function LsaxAddSidNameMapping;
var
  Input: TLsaSidNameMappingOperation;
begin
  // When creating a mapping for a domain, it can only be S-1-5-x
  // where x is in range [SECURITY_MIN_BASE_RID .. SECURITY_MAX_BASE_RID]

  Input.AddInput.DomainName := TLsaUnicodeString.From(Domain);
  Input.AddInput.AccountName := TLsaUnicodeString.From(User);
  Input.AddInput.Sid := Sid;
  Input.AddInput.Flags := 0;

  Result := LsaxManageSidNameMapping(LsaSidNameMappingOperation_Add, Input);
end;

function LsaxRemoveSidNameMapping;
var
  Input: TLsaSidNameMappingOperation;
begin
  Input.RemoveInput.DomainName := TLsaUnicodeString.From(Domain);
  Input.RemoveInput.AccountName := TLsaUnicodeString.From(User);

  Result := LsaxManageSidNameMapping(LsaSidNameMappingOperation_Remove, Input);
end;

end.
