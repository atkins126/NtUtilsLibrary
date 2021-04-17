unit NtUtils.Transactions;

{
  The module introduces functions for working with transactions and related
  object types.
}

interface

uses
  Winapi.WinNt, Ntapi.nttmapi, NtUtils, NtUtils.Objects;

type
  TTransactionProperties = record
    IsolationLevel: Cardinal;
    IsolationFlags: Cardinal;
    Timeout: TLargeInteger;
    Outcome: TTransactionOutcome;
    Description: String;
  end;

  TResourceManagerBasicInfo = record
    ResourceManagerID: TGuid;
    Description: String;
  end;

// Enumerate Kernel Transaction Manager objects on the system
function NtxEnumerateKtmObjects(
  KtmObjectType: TKtmObjectType;
  out Guids: TArray<TGuid>;
  RootObject: THandle = 0
): TNtxStatus;

// ------------------------------ Transaction ------------------------------ //

// Create a transaction object
function NtxCreateTransaction(
  out hxTransaction: IHandle;
  Description: String = '';
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

// Open existing transaction by name
function NtxOpenTransaction(
  out hxTransaction: IHandle;
  DesiredAccess: TTmTxAccessMask;
  Name: String;
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

// Open a transaction object by id
function NtxOpenTransactionById(
  out hxTransaction: IHandle;
  const Uow: TGuid;
  DesiredAccess: TTmTxAccessMask;
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

type
  NtxTransaction = class abstract
    // Query fixed-size information
    class function Query<T>(
      hTransaction: THandle;
      InfoClass: TTransactionInformationClass;
      out Buffer: T
    ): TNtxStatus; static;
  end;

// Query transaction properties
function NtxQueryPropertiesTransaction(
  hTransaction: THandle;
  out Properties: TTransactionProperties
): TNtxStatus;

// Commit a transaction
function NtxCommitTransaction(
  hTransaction: THandle;
  Wait: Boolean = True
): TNtxStatus;

// Abort a transaction
function NtxRollbackTransaction(
  hTransaction: THandle;
  Wait: Boolean = True
): TNtxStatus;

// ------------------------- Registry Transaction -------------------------- //

// Create a registry transaction
function NtxCreateRegistryTransaction(
  out hxTransaction: IHandle;
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

// Open a registry transaction by name
function NtxOpenRegistryTransaction(
  out hxTransaction: IHandle;
  DesiredAccess: TTmTxAccessMask;
  Name: String;
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

// Commit a registry transaction
function NtxCommitRegistryTransaction(
  hTransaction: THandle
): TNtxStatus;

// Abort a registry transaction
function NtxRollbackRegistryTransaction(
  hTransaction: THandle
): TNtxStatus;

// -------------------------- Transaction Manager -------------------------- //

// Open a transaction manager by a name
function NtxOpenTransactionManager(
  out hxTmTm: IHandle;
  DesiredAccess: TTmTmAccessMask;
  Name: String;
  OpenOptions: TTmTmCreateOptions = 0;
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

// Open a transaction manager by a GUID
function NtxOpenTransactionManagerById(
  out hxTmTm: IHandle;
  const TmIdentity: TGuid;
  DesiredAccess: TTmTmAccessMask;
  OpenOptions: TTmTmCreateOptions = 0;
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

type
  NtxTmTm = class
    // Query fixed-size information
    class function Query<T>(
      hTmTm: THandle;
      InfoClass: TTransactionManagerInformationClass;
      out Buffer: T
    ): TNtxStatus; static;
  end;

// Query a LOG file path for a transaction manager
function NtxQueryLogPathTmTx(
  hTmTx: THandle;
  out LogPath: String
): TNtxStatus;

// --------------------------- Resource Manager ---------------------------- //

// Open a resource manager by a GUID
function NtxOpenResourceManagerById(
  out hxTmRm: IHandle;
  const RMGuid: TGuid;
  TmHandle: THandle;
  DesiredAccess: TTmRmAccessMask;
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

// Query basic information about a resource Manager
function NtxQueryBasicTmRm(
  hTmRm: THandle;
  out BasicInfo: TResourceManagerBasicInfo
): TNtxStatus;

// ------------------------------ Enlistment ------------------------------- //

// Open an enlistment
function NtxOpenEnlistmentById(
  out hxTmEn: IHandle;
  const EnlistmentGuid: TGuid;
  RmHandle: THandle;
  DesiredAccess: TTmEnAccessMask;
  ObjectAttributes: IObjectAttributes = nil
): TNtxStatus;

type
  NtxTmEn = class
    // Query fixed-size information
    class function Query<T>(
      hTmEn: THandle;
      InfoClass: TEnlistmentInformationClass;
      out Buffer: T
    ): TNtxStatus; static;
  end;

implementation

uses
  Ntapi.ntdef, Ntapi.ntstatus, Ntapi.ntrtl, DelphiUtils.AutoObject, NtUtils.Ldr;

function NtxEnumerateKtmObjects;
var
  Cursor: TKtmObjectCursor;
  Required: Cardinal;
begin
  Result.Location := 'NtEnumerateTransactionObject';
  Result.LastCall.AttachInfoClass(KtmObjectType);

  case KtmObjectType of
    KTMOBJECT_TRANSACTION:
      if RootObject <> 0 then
        Result.LastCall.Expects<TTmTmAccessMask>(
          TRANSACTIONMANAGER_QUERY_INFORMATION);

    KTMOBJECT_RESOURCE_MANAGER:
      Result.LastCall.Expects<TTmTmAccessMask>(
        TRANSACTIONMANAGER_QUERY_INFORMATION);

    KTMOBJECT_ENLISTMENT:
      Result.LastCall.Expects<TTmRmAccessMask>(
        RESOURCEMANAGER_QUERY_INFORMATION);
  end;

  FillChar(Cursor, SizeOf(Cursor), 0);
  SetLength(Guids, 0);

  repeat
    Result.Status := NtEnumerateTransactionObject(RootObject, KtmObjectType,
      @Cursor, SizeOf(Cursor), Required);

    if not Result.IsSuccess then
      Break;

    SetLength(Guids, Length(Guids) + 1);
    Guids[High(Guids)] := Cursor.ObjectIds[0];
  until False;

  if Result.Status = STATUS_NO_MORE_ENTRIES then
    Result.Status := STATUS_SUCCESS;
end;

// Transactions

function NtxCreateTransaction;
var
  hTransaction: THandle;
begin
  Result.Location := 'NtCreateTransaction';
  Result.Status := NtCreateTransaction(
    hTransaction,
    AccessMaskOverride(TRANSACTION_ALL_ACCESS, ObjectAttributes),
    AttributesRefOrNil(ObjectAttributes),
    nil,
    0,
    0,
    0,
    0,
    nil,
    TNtUnicodeString.From(Description).RefOrNull
  );

  if Result.IsSuccess then
    hxTransaction := TAutoHandle.Capture(hTransaction);
end;

function NtxOpenTransaction;
var
  hTransaction: THandle;
begin
  Result.Location := 'NtOpenTransaction';
  Result.LastCall.AttachInfoClass(DesiredAccess);

  Result.Status := NtOpenTransaction(
    hTransaction,
    DesiredAccess,
    AttributeBuilder(ObjectAttributes).UseName(Name).ToNative,
    nil,
    0
  );

  if Result.IsSuccess then
    hxTransaction := TAutoHandle.Capture(hTransaction);
end;

function NtxOpenTransactionById;
var
  hTransaction: THandle;
begin
  Result.Location := 'NtOpenTransaction';
  Result.LastCall.AttachAccess(DesiredAccess);

  Result.Status := NtOpenTransaction(
    hTransaction,
    DesiredAccess,
    AttributesRefOrNil(ObjectAttributes),
    @Uow,
    0
  );

  if Result.IsSuccess then
    hxTransaction := TAutoHandle.Capture(hTransaction);
end;

class function NtxTransaction.Query<T>;
begin
  Result.Location := 'NtQueryInformationTransaction';
  Result.LastCall.AttachInfoClass(InfoClass);
  Result.LastCall.Expects<TTmTxAccessMask>(TRANSACTION_QUERY_INFORMATION);

  Result.Status := NtQueryInformationTransaction(hTransaction, InfoClass,
    @Buffer, SizeOf(Buffer), nil);
end;

function NtxQueryPropertiesTransaction;
const
  BUFFER_SIZE = SizeOf(TTransactionPropertiesInformation) +
    MAX_TRANSACTION_DESCRIPTION_LENGTH * SizeOf(WideChar);
var
  xMemory: IMemory<PTransactionPropertiesInformation>;
  Required: Cardinal;
begin
  Result.Location := 'NtQueryInformationTransaction';
  Result.LastCall.AttachInfoClass(TransactionPropertiesInformation);
  Result.LastCall.Expects<TTmTxAccessMask>(TRANSACTION_QUERY_INFORMATION);

  IMemory(xMemory) := TAutoMemory.Allocate(BUFFER_SIZE);
  repeat
    Required := 0;
    Result.Status := NtQueryInformationTransaction(hTransaction,
      TransactionPropertiesInformation, xMemory.Data, BUFFER_SIZE, @Required);
  until not NtxExpandBufferEx(Result, IMemory(xMemory), Required, nil);

  if Result.IsSuccess then
  begin
    Properties.IsolationLevel := xMemory.Data.IsolationLevel;
    Properties.IsolationFlags := xMemory.Data.IsolationFlags;
    Properties.Timeout := xMemory.Data.Timeout;
    Properties.Outcome := xMemory.Data.Outcome;
    SetString(Properties.Description, xMemory.Data.Description,
      xMemory.Data.DescriptionLength div SizeOf(WideChar));
  end;
end;

function NtxCommitTransaction;
begin
  Result.Location := 'NtCommitTransaction';
  Result.LastCall.Expects<TTmTxAccessMask>(TRANSACTION_COMMIT);
  Result.Status := NtCommitTransaction(hTransaction, Wait);
end;

function NtxRollbackTransaction;
begin
  Result.Location := 'NtRollbackTransaction';
  Result.LastCall.Expects<TTmTxAccessMask>(TRANSACTION_ROLLBACK);
  Result.Status := NtRollbackTransaction(hTransaction, Wait);
end;

// Registry Transactions

function NtxCreateRegistryTransaction;
var
  hTransaction: THandle;
begin
  Result := LdrxCheckNtDelayedImport('NtCreateRegistryTransaction');

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'NtCreateRegistryTransaction';
  Result.Status := NtCreateRegistryTransaction(
    hTransaction,
    AccessMaskOverride(TRANSACTION_ALL_ACCESS, ObjectAttributes),
    AttributesRefOrNil(ObjectAttributes),
    0
  );

  if Result.IsSuccess then
    hxTransaction := TAutoHandle.Capture(hTransaction);
end;

function NtxOpenRegistryTransaction;
var
  hTransaction: THandle;
begin
  Result := LdrxCheckNtDelayedImport('NtOpenRegistryTransaction');

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'NtOpenRegistryTransaction';
  Result.LastCall.AttachAccess(DesiredAccess);

  Result.Status := NtOpenRegistryTransaction(
    hTransaction,
    DesiredAccess,
    AttributeBuilder(ObjectAttributes).UseName(Name).ToNative
  );

  if Result.IsSuccess then
    hxTransaction := TAutoHandle.Capture(hTransaction);
end;

function NtxCommitRegistryTransaction;
begin
  Result := LdrxCheckNtDelayedImport('NtCommitRegistryTransaction');

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'NtCommitRegistryTransaction';
  Result.LastCall.Expects<TTmTxAccessMask>(TRANSACTION_COMMIT);
  Result.Status := NtCommitRegistryTransaction(hTransaction, 0);
end;

function NtxRollbackRegistryTransaction;
begin
  Result := LdrxCheckNtDelayedImport('NtRollbackRegistryTransaction');

  if not Result.IsSuccess then
    Exit;

  Result.Location := 'NtRollbackRegistryTransaction';
  Result.LastCall.Expects<TTmTxAccessMask>(TRANSACTION_ROLLBACK);
  Result.Status := NtRollbackRegistryTransaction(hTransaction, 0);
end;

// Transaction Manager

function NtxOpenTransactionManager;
var
  hTransactionManager: THandle;
begin
  Result.Location := 'NtOpenTransactionManager';
  Result.LastCall.AttachAccess(DesiredAccess);

  Result.Status := NtOpenTransactionManager(
    hTransactionManager,
    DesiredAccess,
    AttributeBuilder(ObjectAttributes).UseName(Name).ToNative,
    nil,
    nil,
    OpenOptions
  );

  if Result.IsSuccess then
    hxTmTm := TAutoHandle.Capture(hTransactionManager);
end;

function NtxOpenTransactionManagerById;
var
  hTmTm: THandle;
begin
  Result.Location := 'NtOpenTransactionManager';
  Result.LastCall.AttachAccess(DesiredAccess);

  Result.Status := NtOpenTransactionManager(
    hTmTm,
    DesiredAccess,
    AttributesRefOrNil(ObjectAttributes),
    nil,
    @TmIdentity,
    OpenOptions
  );

  if Result.IsSuccess then
    hxTmTm := TAutoHandle.Capture(hTmTm);
end;

class function NtxTmTm.Query<T>;
begin
  Result.Location := 'NtQueryInformationTransactionManager';
  Result.LastCall.AttachInfoClass(InfoClass);

  Result.Status := NtQueryInformationTransactionManager(hTmTm,
    InfoClass, @Buffer, SizeOf(Buffer), nil);
end;

function NtxQueryLogPathTmTx;
var
  xMemory: IMemory<PTransactionManagerLogPathInformation>;
  Required: Cardinal;
begin
  Result.Location := 'NtQueryInformationTransactionManager';
  Result.LastCall.AttachInfoClass(TransactionManagerLogPathInformation);
  Result.LastCall.Expects<TTmTmAccessMask>(TRANSACTIONMANAGER_QUERY_INFORMATION);

  // Initial size
  IMemory(xMemory) := TAutoMemory.Allocate(
    SizeOf(TTransactionManagerLogPathInformation) +
    RtlGetLongestNtPathLength * SizeOf(WideChar));

  repeat
    Required := 0;
    Result.Status := NtQueryInformationTransactionManager(hTmTx,
      TransactionManagerLogPathInformation, xMemory.Data, xMemory.Size,
      @Required);
  until not NtxExpandBufferEx(Result, IMemory(xMemory), Required, nil);

  if Result.IsSuccess then
    SetString(LogPath, PWideChar(@xMemory.Data.LogPath),
      xMemory.Data.LogPathLength div SizeOf(WideChar));
end;

// Resource Manager

function NtxOpenResourceManagerById;
var
  hTmRm: THandle;
begin
  Result.Location := 'NtOpenResourceManager';
  Result.LastCall.AttachAccess(DesiredAccess);
  Result.LastCall.Expects<TTmTmAccessMask>(TRANSACTIONMANAGER_QUERY_INFORMATION);

  Result.Status := NtOpenResourceManager(
    hTmRm,
    DesiredAccess,
    TmHandle,
    @RMGuid,
    AttributesRefOrNil(ObjectAttributes)
  );

  if Result.IsSuccess then
    hxTmRm := TAutoHandle.Capture(hTmRm);
end;

function NtxQueryBasicTmRm;
const
  BUFFER_SIZE = SizeOf(TResourceManagerBasicInformation) +
    MAX_RESOURCEMANAGER_DESCRIPTION_LENGTH * SizeOf(WideChar);
var
  xMemory: IMemory<PResourceManagerBasicInformation>;
  Required: Cardinal;
begin
  Result.Location := 'NtQueryInformationResourceManager';
  Result.LastCall.AttachInfoClass(ResourceManagerBasicInformation);
  Result.LastCall.Expects<TTmRmAccessMask>(RESOURCEMANAGER_QUERY_INFORMATION);

  IMemory(xMemory) := TAutoMemory.Allocate(BUFFER_SIZE);
  repeat
    Required := 0;
    Result.Status := NtQueryInformationResourceManager(hTmRm,
      ResourceManagerBasicInformation, xMemory.Data, BUFFER_SIZE, @Required);
  until not NtxExpandBufferEx(Result, IMemory(xMemory), Required, nil);

  if Result.IsSuccess then
  begin
    BasicInfo.ResourceManagerID := xMemory.Data.ResourceManagerId;
    SetString(BasicInfo.Description, xMemory.Data.Description,
      xMemory.Data.DescriptionLength div SizeOf(WideChar));
  end;
end;

// Enlistment

function NtxOpenEnlistmentById;
var
  hTmEn: THandle;
begin
  Result.Location := 'NtOpenEnlistment';
  Result.LastCall.AttachAccess(DesiredAccess);
  Result.LastCall.Expects<TTmRmAccessMask>(RESOURCEMANAGER_QUERY_INFORMATION);

  Result.Status := NtOpenEnlistment(
    hTmEn,
    DesiredAccess,
    RmHandle,
    EnlistmentGuid,
    AttributesRefOrNil(ObjectAttributes)
  );

  if Result.IsSuccess then
    hxTmEn := TAutoHandle.Capture(hTmEn);
end;

class function NtxTmEn.Query<T>;
begin
  Result.Location := 'NtQueryInformationEnlistment';
  Result.LastCall.AttachInfoClass(InfoClass);

  Result.Status := NtQueryInformationEnlistment(hTmEn, InfoClass, @Buffer,
    SizeOf(Buffer), nil);
end;

end.
