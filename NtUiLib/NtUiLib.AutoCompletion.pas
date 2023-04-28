unit NtUiLib.AutoCompletion;

{
  The module provides functions for creating custom auto-completion lists
  similar to those created by SHAutoComplete.
}

interface

uses
  Ntapi.WinUser, Ntapi.Shlwapi, NtUtils;

type
  TExpandProvider = reference to function (
    const Root: String;
    out Suggestions: TArray<String>
  ): TNtxStatus;

// Add a static list of suggestions to an Edit-derived control.
function ShlxEnableStaticSuggestions(
  EditControl: THwnd;
  const Strings: TArray<String>;
  Options: Cardinal = ACO_AUTOSUGGEST or ACO_UPDOWNKEYDROPSLIST
): TNtxStatus;

// Register dynamic (hierarchical) suggestions for an Edit-derived control.
function ShlxEnableDynamicSuggestions(
  EditControl: THwnd;
  const Provider: TExpandProvider;
  Options: Cardinal = ACO_AUTOSUGGEST or ACO_UPDOWNKEYDROPSLIST
): TNtxStatus;

implementation

uses
  Ntapi.WinNt, Ntapi.ObjBase, Ntapi.ObjIdl, Ntapi.WinError, NtUtils.WinUser,
  DelphiApi.Reflection, NtUtils.Errors, NtUtils.Com;

{$BOOLEVAL OFF}
{$IFOPT R+}{$DEFINE R+}{$ENDIF}
{$IFOPT Q+}{$DEFINE Q+}{$ENDIF}

type
  TStringEnumerator = class(TInterfacedObject, IEnumString, IACList)
  private
    function Next(
      [in, NumberOfElements] Count: Integer;
      [out, WritesTo, ReleaseWith('CoTaskMemFree')] out Elements:
        TAnysizeArray<PWideChar>;
      [out, NumberOfElements] out Fetched: Integer
    ): HResult; stdcall;

    function Skip(
      [in,  NumberOfElements] Count: Integer
    ): HResult; stdcall;

    function Reset(
    ): HResult; stdcall;

    function Clone(
      [out] out Enm: IEnumString
    ): HResult; stdcall;

    function Expand(Root: PWideChar): HResult; stdcall;
  protected
    EditControl: THwnd;
    Provider: TExpandProvider;
    Strings: TArray<String>;
    Index: Integer;
    constructor CreateCopy(Source: TStringEnumerator);
  public
    constructor CreateStatic(EditControl: THwnd; Strings: TArray<String>);
    constructor CreateDynamic(EditControl: THwnd; Provider: TExpandProvider);
  end;

{ TStringEnumerator }

function TStringEnumerator.Clone;
begin
  Enm := TStringEnumerator.CreateCopy(Self);
  Result := S_OK;
end;

constructor TStringEnumerator.CreateCopy;
begin
  inherited Create;
  EditControl := Source.EditControl;
  Provider := Source.Provider;
  Strings := Source.Strings;
  Index := Source.Index;
end;

constructor TStringEnumerator.CreateDynamic;
begin
  inherited Create;
  Self.EditControl := EditControl;
  Self.Provider := Provider;
end;

constructor TStringEnumerator.CreateStatic;
begin
  inherited Create;
  Self.EditControl := EditControl;
  Self.Strings := Strings;
end;

function TStringEnumerator.Expand;
begin
  // Use the callback to enumerate suggestions in a hierarchy
  if Assigned(Provider) then
    Result := Provider(String(Root), Strings).HResult
  else
    Result := S_FALSE;
end;

function TStringEnumerator.Next;
var
  i: Integer;
  Buffer: PWideChar;
begin
  i := 0;

  // Return strings until we satisfy the count or have nothing left
  while (i < Count) and (Index <= High(Strings)) do
  begin
    // The caller is responsble for freeing each string
    Buffer := CoTaskMemAlloc(StringSizeZero(Strings[Index]));

    if not Assigned(Buffer) then
      Exit(TWin32Error(ERROR_NOT_ENOUGH_MEMORY).ToHResult);

    MarshalString(Strings[Index], Buffer);
    Elements{$R-}[i]{$IFDEF R+}{$R+}{$ENDIF} := Buffer;
    Inc(i);
    Inc(Index);
  end;

  Fetched := i;

  if i = Count then
    Result := S_OK
  else
    Result := S_FALSE;
end;

function TStringEnumerator.Reset;
var
  CurrentText: String;
begin
  // For some reason, AutoComplete does not call Expand on the root; fix it.
  if UsrxGetWindowText(EditControl, CurrentText).IsSuccess and
    (Pos('\', CurrentText) <= 0) then
    Expand(nil);

  Index := 0;
  Result := S_OK;
end;

function TStringEnumerator.Skip;
begin
  Inc(Index, Count);

  if Index > High(Strings) then
    Result := S_FALSE
  else
    Result := S_OK;
end;

{ Functions }

function ShlxpEnableSuggestions(
  EditControl: THwnd;
  const ACList: IUnknown;
  Options: Cardinal
): TNtxStatus;
var
  AutoComplete: IAutoComplete2;
begin
  // Create an instance of CLSID_AutoComplete (provided by the OS)
  Result := ComxCreateInstance(CLSID_AutoComplete, IAutoComplete2, AutoComplete,
    CLSCTX_INPROC_SERVER);
  Result.LastCall.Parameter := 'CLSID_AutoComplete';

  if not Result.IsSuccess then
    Exit;

  // Adjust options
  Result.Location := 'IAutoComplete2::SetOptions';
  Result.HResult := AutoComplete.SetOptions(Options);

  if not Result.IsSuccess then
    Exit;

  // Register our suggestions
  Result.Location := 'IAutoComplete::Init';
  Result.HResult := AutoComplete.Init(EditControl, ACList, nil, nil);
end;

function ShlxEnableStaticSuggestions;
var
  ACList: IACList;
begin
  // Save the object to an interface variable since it we pass it as a const
  ACList := TStringEnumerator.CreateStatic(EditControl, Strings);

  Result := ShlxpEnableSuggestions(EditControl, ACList, Options);
end;

function ShlxEnableDynamicSuggestions;
var
  ACList: IACList;
begin
  // Save the object to an interface variable since it we pass it as a const
  ACList := TStringEnumerator.CreateDynamic(EditControl, Provider);

  Result := ShlxpEnableSuggestions(EditControl, ACList, Options);
end;

end.
