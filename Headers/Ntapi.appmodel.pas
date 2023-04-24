unit Ntapi.appmodel;

{
  This module includes definitions for inspecting packaged applocations.
}

interface

{$WARN SYMBOL_PLATFORM OFF}
{$MINENUMSIZE 4}

uses
  Ntapi.WinNt, Ntapi.ntdef, Ntapi.ntseapi, Ntapi.ntpebteb, Ntapi.Versions,
  Ntapi.WinUser, DelphiApi.Reflection;

const
  // SDK::appmodel.h - information flags
  PACKAGE_INFORMATION_BASIC = $00000000;
  PACKAGE_INFORMATION_FULL = $00000100;

  // SDK::appmodel.h - filter flags
  PACKAGE_FILTER_HEAD = $00000010;
  PACKAGE_FILTER_DIRECT = $00000020;
  PACKAGE_FILTER_RESOURCE = $00000040;
  PACKAGE_FILTER_BUNDLE = $00000080;
  PACKAGE_FILTER_OPTIONAL = $00020000;
  PACKAGE_FILTER_IS_IN_RELATED_SET = $00040000;
  PACKAGE_FILTER_STATIC = $00080000;
  PACKAGE_FILTER_DYNAMIC = $00100000;
  PACKAGE_FILTER_HOSTRUNTIME = $00200000; // Win 10 20H2+

  // SDK::appmodel.h - package properties
  PACKAGE_PROPERTY_FRAMEWORK = $00000001;
  PACKAGE_PROPERTY_RESOURCE = $00000002;
  PACKAGE_PROPERTY_BUNDLE = $00000004;
  PACKAGE_PROPERTY_OPTIONAL = $00000008;
  PACKAGE_PROPERTY_HEAD = $00000010;   // rev
  PACKAGE_PROPERTY_DIRECT = $00000020; // rev
  PACKAGE_PROPERTY_DEVELOPMENT_MODE = $00010000;
  PACKAGE_PROPERTY_IS_IN_RELATED_SET = $00040000;
  PACKAGE_PROPERTY_STATIC = $00080000;
  PACKAGE_PROPERTY_DYNAMIC = $00100000;
  PACKAGE_PROPERTY_HOSTRUNTIME = $00200000; // Win 10 20H2+

  // Windows Internals book - package claim flags
  PSM_ACTIVATION_TOKEN_PACKAGED_APPLICATION = $0001;
  PSM_ACTIVATION_TOKEN_SHARED_ENTITY = $0002;
  PSM_ACTIVATION_TOKEN_FULL_TRUST = $0004;
  PSM_ACTIVATION_TOKEN_NATIVE_SERVICE = $0008;
  PSM_ACTIVATION_TOKEN_DEVELOPMENT_APP = $0010;
  PSM_ACTIVATION_TOKEN_BREAKAWAY_INHIBITED = $0020;
  PSM_ACTIVATION_TOKEN_RUNTIME_BROKER = $0040; // rev
  PSM_ACTIVATION_TOKEN_WIN32ALACARTE_PROCESS = $00010000; // rev

  // rev - attributes for RtlQueryPackageClaims
  PACKAGE_ATTRIBUTE_SYSAPPID_PRESENT = $0001;
  PACKAGE_ATTRIBUTE_PKG_CLAIM_PRESENT = $0002;
  PACKAGE_ATTRIBUTE_SKUID_PRESENT = $0004;
  PACKAGE_ATTRIBUTE_XBOX_LI_PRESENT = $0008;

  // rev - helpers for TAppModelPolicy_PolicyValue
  APP_MODEL_POLICY_TYPE_SHIFT = 16;
  APP_MODEL_POLICY_TYPE_MASK = $FFFF0000;
  APP_MODEL_POLICY_VALUE_MASK = $0000FFFF;

  // Desktop AppX activation options
  DAXAO_ELEVATE = $00000001;
  DAXAO_NONPACKAGED_EXE = $00000002;
  DAXAO_NONPACKAGED_EXE_PROCESS_TREE = $00000004;   // Win 10 RS2+
  DAXAO_NO_ERROR_UI = $00000008;                    // Win 10 20H1+
  DAXAO_CHECK_FOR_APPINSTALLER_UPDATES = $00000010; // Win 10 20H1+ (was 0x40 in 19H1 & 19H2)
  DAXAO_CENTENNIAL_PROCESS = $00000020;             // Win 10 20H1+
  DAXAO_UNIVERSAL_PROCESS = $00000040;              // Win 10 20H1+
  DAXAO_WIN32ALACARTE_PROCESS = $00000080;          // Win 10 20H1+
  DAXAO_PARTIAL_TRUST = $00000100;                  // Win 10 20H1+
  DAXAO_UNIVERSAL_CONSOLE = $00000200;              // Win 10 20H1+

  CLSID_DesktopAppXActivator: TGuid = '{168EB462-775F-42AE-9111-D714B2306C2E}';

type
  // SDK::appmodel.h
  [MinOSVersion(OsWin8)]
  [SDKName('PACKAGE_VERSION')]
  TPackageVersion = record
    Revision: Word;
    Build: Word;
    Minor: Word;
    Major: Word;
  end;

  // SDK::appmodel.h
  [MinOSVersion(OsWin8)]
  [SDKName('PACKAGE_ID')]
  TPackageId = record
    [Unlisted] Reserved: Cardinal;
    ProcessorArchitecture: TProcessorArchitecture;
    [Unlisted] Padding: Word;
    Version: TPackageVersion;
    Name: PWideChar;
    Publisher: PWideChar;
    ResourceID: PWideChar;
    PublisherID: PWideChar;
  end;
  PPackageId = ^TPackageId;

  // SDK::appmodel.h
  [MinOSVersion(OsWin1019H1)]
  [SDKName('PackagePathType')]
  [NamingStyle(nsCamelCase, 'PackagePathType_')]
  TPackagePathType = (
    PackagePathType_Install = 0,
    PackagePathType_Mutable = 1,
    PackagePathType_Effective = 2,
    [MinOSVersion(OsWin1020H1)] PackagePathType_MachineExternal = 3,
    [MinOSVersion(OsWin1020H1)] PackagePathType_UserExternal = 4,
    [MinOSVersion(OsWin1020H1)] PackagePathType_EffectiveExternal = 5
  );

  [FlagName(PACKAGE_INFORMATION_BASIC, 'Basic')]
  [FlagName(PACKAGE_INFORMATION_FULL, 'Full')]
  TPackageInformationFlags = type Cardinal;

  TPackageFullNames = TAnysizeArray<PWideChar>;
  PPackageFullNames = ^TPackageFullNames;

  [FlagName(PACKAGE_FILTER_HEAD, 'Head Package')]
  [FlagName(PACKAGE_FILTER_DIRECT, 'Directly Dependent')]
  [FlagName(PACKAGE_FILTER_RESOURCE, 'Resource')]
  [FlagName(PACKAGE_FILTER_BUNDLE, 'Bundle')]
  [FlagName(PACKAGE_FILTER_OPTIONAL, 'Optional')]
  [FlagName(PACKAGE_FILTER_IS_IN_RELATED_SET, 'In Related Set')]
  [FlagName(PACKAGE_FILTER_STATIC, 'Static')]
  [FlagName(PACKAGE_FILTER_DYNAMIC, 'Dynamic')]
  [FlagName(PACKAGE_FILTER_HOSTRUNTIME, 'Host Runtime')]
  TPackageFilters = type Cardinal;

  [FlagName(PACKAGE_PROPERTY_FRAMEWORK, 'Framework')]
  [FlagName(PACKAGE_PROPERTY_RESOURCE, 'Resource')]
  [FlagName(PACKAGE_PROPERTY_BUNDLE, 'Bundle')]
  [FlagName(PACKAGE_PROPERTY_OPTIONAL, 'Optional')]
  [FlagName(PACKAGE_PROPERTY_HEAD, 'Head Package')]
  [FlagName(PACKAGE_PROPERTY_DIRECT, 'Directly Dependent')]
  [FlagName(PACKAGE_PROPERTY_DEVELOPMENT_MODE, 'Development Mode')]
  [FlagName(PACKAGE_PROPERTY_IS_IN_RELATED_SET, 'In Related Set')]
  [FlagName(PACKAGE_PROPERTY_STATIC, 'Static')]
  [FlagName(PACKAGE_PROPERTY_DYNAMIC, 'Dynamic')]
  [FlagName(PACKAGE_PROPERTY_HOSTRUNTIME, 'Host Runtime')]
  TPackageProperties = type Cardinal;

  TPackagePropertiesArray = TAnysizeArray<TPackageProperties>;
  PPackagePropertiesArray = ^TPackagePropertiesArray;

  // SDK::appmodel.h
  [SDKName('PackageOrigin')]
  [NamingStyle(nsCamelCase, 'PackageOrigin_')]
  TPackageOrigin = (
    PackageOrigin_Unknown = 0,
    PackageOrigin_Unsigned = 1,
    PackageOrigin_Inbox = 2,
    PackageOrigin_Store = 3,
    PackageOrigin_DeveloperUnsigned = 4,
    PackageOrigin_DeveloperSigned = 5,
    PackageOrigin_LineOfBusiness = 6
  );

  [FlagName(PSM_ACTIVATION_TOKEN_PACKAGED_APPLICATION, 'Packaged Application')]
  [FlagName(PSM_ACTIVATION_TOKEN_SHARED_ENTITY, 'Shared Entity')]
  [FlagName(PSM_ACTIVATION_TOKEN_FULL_TRUST, 'Full Trust')]
  [FlagName(PSM_ACTIVATION_TOKEN_NATIVE_SERVICE, 'Native Service')]
  [FlagName(PSM_ACTIVATION_TOKEN_DEVELOPMENT_APP, 'Development App')]
  [FlagName(PSM_ACTIVATION_TOKEN_BREAKAWAY_INHIBITED, 'Breakaway Inhibited')]
  [FlagName(PSM_ACTIVATION_TOKEN_RUNTIME_BROKER, 'Runtime Broker')]
  [FlagName(PSM_ACTIVATION_TOKEN_WIN32ALACARTE_PROCESS, 'Win32 A-La-Carte Process')]
  TPackageClaimFlags = type Cardinal;

  // PHNT::ntrtl.h
  [SDKName('PS_PKG_CLAIM')]
  TPsPkgClaim = record
    Flags: TPackageClaimFlags;
    Origin: TPackageOrigin;
  end;
  PPsPkgClaim = ^TPsPkgClaim;

  [FlagName(PACKAGE_ATTRIBUTE_SYSAPPID_PRESENT, 'WIN://SYSAPPID')]
  [FlagName(PACKAGE_ATTRIBUTE_PKG_CLAIM_PRESENT, 'WIN://PKG')]
  [FlagName(PACKAGE_ATTRIBUTE_SKUID_PRESENT, 'WP://SKUID')]
  [FlagName(PACKAGE_ATTRIBUTE_XBOX_LI_PRESENT, 'XBOX://LI')]
  TPackagePresentAttributes = type UInt64;
  PPackagePresentAttributes = ^TPackagePresentAttributes;

  // SDK::appmodel.h
  [MinOSVersion(OsWin8)]
  [SDKName('PACKAGE_INFO')]
  TPackageInfo = record
    Reserved: Cardinal;
    Flags: TPackageProperties;
    Path: PWideChar;
    PackageFullName: PWideChar;
    PackageFamilyName: PWideChar;
    [Aggregate] PackageId: TPackageId;
  end;
  PPackageInfo = ^TPackageInfo;

  TPackageInfoArray = TAnysizeArray<TPackageInfo>;
  PPackageInfoArray = ^TPackageInfoArray;

  // SDK::appmodel.h
  [SDKName('PACKAGE_INFO_REFERENCE')]
  TPackageInfoReference = type Pointer;

  TAppIdArray = TAnysizeArray<PWideChar>;
  PAppIdArray = ^TAppIdArray;

  { Properties }

  // private
  [SDKName('PACKAGE_CONTEXT_REFERENCE')]
  TPackageContextReference = record end;
  PPackageContextReference = ^TPackageContextReference;

  // private
  [MinOSVersion(OsWin81)]
  [SDKName('PackageProperty')]
  [NamingStyle(nsCamelCase, 'PackageProperty_'), Range(1)]
  TPackageProperty = (
    [Reserved] PackageProperty_Reserved = 0,
    PackageProperty_Name = 1,                  // q: PWideChar
    PackageProperty_Version = 2,               // q: TPackageVersion
    PackageProperty_Architecture = 3,          // q: Cardinal (TProcessorArchitecture)
    PackageProperty_ResourceId = 4,            // q: PWideChar
    PackageProperty_Publisher = 5,             // q: PWideChar
    PackageProperty_PublisherId = 6,           // q: PWideChar
    PackageProperty_FamilyName = 7,            // q: PWideChar
    PackageProperty_FullName = 8,              // q: PWideChar
    PackageProperty_Flags = 9,                 // q: Cardinal (maybe Windows::Internal::StateRepository::PackageFlags / StateRepository::Cache::CachePackageFlags?)
    PackageProperty_InstalledLocation = 10,    // q: PWideChar
    PackageProperty_DisplayName = 11,          // q: PWideChar
    PackageProperty_PublisherDisplayName = 12, // q: PWideChar
    PackageProperty_Description = 13,          // q: PWideChar
    PackageProperty_Logo = 14,                 // q: PWideChar
    PackageProperty_PackageOrigin = 15         // q: TPackageOrigin
  );

  // private
  [SDKName('PACKAGE_APPLICATION_CONTEXT_REFERENCE')]
  TPackageApplicationContextReference = record end;
  PPackageApplicationContextReference = ^TPackageApplicationContextReference;

  // private
  [MinOSVersion(OsWin81)]
  [SDKName('PackageApplicationProperty')]
  [NamingStyle(nsCamelCase, 'PackageApplicationProperty_'), Range(1)]
  TPackageApplicationProperty = (
    [Reserved] PackageAppProperty_Reserved = 0,
    PackageApplicationProperty_Aumid = 1,                        // q: PWideChar
    PackageApplicationProperty_Praid = 2,                        // q: PWideChar
    PackageApplicationProperty_DisplayName = 3,                  // q: PWideChar
    PackageApplicationProperty_Description = 4,                  // q: PWideChar
    PackageApplicationProperty_Logo = 5,                         // q: PWideChar
    PackageApplicationProperty_SmallLogo = 6,                    // q: PWideChar
    PackageApplicationProperty_ForegroundText = 7,               // q: Cardinal
    PackageApplicationProperty_ForegroundTextString = 8,         // q: PWideChar
    PackageApplicationProperty_BackgroundColor = 9,              // q: Cardinal
    PackageApplicationProperty_StartPage = 10,                   // q: PWideChar
    PackageApplicationProperty_ContentURIRulesCount = 11,        // q: Cardinal
    PackageApplicationProperty_ContentURIRules = 12,             // q: PWideMultiSz
    PackageApplicationProperty_StaticContentURIRulesCount = 13,  // q: Cardinal
    PackageApplicationProperty_StaticContentURIRules = 14,       // q: PWideMultiSz
    PackageApplicationProperty_DynamicContentURIRulesCount = 15, // q: Cardinal
    PackageApplicationProperty_DynamicContentURIRules = 16       // q: PWideMultiSz
  );

  // private
  [SDKName('PACKAGE_RESOURCES_CONTEXT_REFERENCE')]
  TPackageResourcesContextReference = record end;
  PPackageResourcesContextReference = ^TPackageResourcesContextReference;

  // private
  [MinOSVersion(OsWin81)]
  [SDKName('PackageResourcesProperty')]
  [NamingStyle(nsCamelCase, 'PackageResourcesProperty_'), Range(1)]
  TPackageResourcesProperty = (
    [Reserved] PackageResourceProperty_Reserved = 0,
    PackageResourcesProperty_DisplayName = 1,
    PackageResourcesProperty_PublisherDisplayName = 2,
    PackageResourcesProperty_Description = 3,
    PackageResourcesProperty_Logo = 4,
    PackageResourcesProperty_SmallLogo = 5,
    PackageResourcesProperty_StartPage = 6
  );

  // private
  [SDKName('PACKAGE_SECURITY_CONTEXT_REFERENCE')]
  TPackageSecurityContextReference = record end;
  PPackageSecurityContextReference = ^TPackageSecurityContextReference;

  // private
  [SDKName('PackageSecurityProperty')]
  [NamingStyle(nsCamelCase, 'PackageSecurityProperty_'), Range(1)]
  TPackageSecurityProperty = (
    [Reserved] PackageSecurityProperty_Reserved = 0,
    PackageSecurityProperty_SecurityFlags = 1,     // q: Cardinal
    PackageSecurityProperty_AppContainerSID = 2,   // q: PSid
    PackageSecurityProperty_CapabilitiesCount = 3, // q: Cardinal
    PackageSecurityProperty_Capabilities = 4       // q: PSid[]
  );

  // private
  [SDKName('TARGET_PLATFORM_CONTEXT_REFERENCE')]
  TTargetPlatformContextReference = record end;
  PTargetPlatformContextReference = ^TTargetPlatformContextReference;

  // private
  [MinOSVersion(OsWin10TH1)]
  [SDKName('TargetPlatformProperty')]
  [NamingStyle(nsCamelCase, 'TargetPlatformProperty_'), Range(1)]
  TTargetPlatformProperty = (
    [Reserved] TargetPlatformProperty_Reserved = 0,
    TargetPlatformProperty_Platform = 1,   // q: Cardinal
    TargetPlatformProperty_MinVersion = 2, // q: TPackageVersion
    TargetPlatformProperty_MaxVersion = 3  // q: TPackageVersion
  );

  // private
  [SDKName('PACKAGE_GLOBALIZATION_CONTEXT_REFERENCE')]
  TPackageGlobalizationContextReference = record end;
  PPackageGlobalizationContextReference = ^TPackageGlobalizationContextReference;

  // private
  [MinOSVersion(OsWin1020H1)]
  [SDKName('PackageGlobalizationProperty')]
  [NamingStyle(nsCamelCase, 'PackageGlobalizationProperty_'), Range(1)]
  TPackageGlobalizationProperty = (
    [Reserved] PackageGlobalizationProperty_Reserved = 0,
    PackageGlobalizationProperty_ForceUtf8 = 1,                // q: LongBool
    PackageGlobalizationProperty_UseWindowsDisplayLanguage = 2 // q: LongBool
  );

  { AppModel }

  // private - app model policy info classes
  [MinOSVersion(OsWin10RS1)]
  [SDKName('AppModelPolicy_Type')]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_Type_'), Range(1)]
  TAppModelPolicyType = (
    [Reserved] AppModelPolicy_Type_Unspecified = $0,
    AppModelPolicy_Type_LifecycleManager = $1,
    AppModelPolicy_Type_AppdataAccess = $2,
    AppModelPolicy_Type_WindowingModel = $3,
    AppModelPolicy_Type_DLLSearchOrder = $4,
    AppModelPolicy_Type_Fusion = $5,
    AppModelPolicy_Type_NonWindowsCodecLoading = $6,
    AppModelPolicy_Type_ProcessEnd = $7,
    AppModelPolicy_Type_BeginThreadInit = $8,
    AppModelPolicy_Type_DeveloperInformation = $9,
    AppModelPolicy_Type_CreateFileAccess = $A,
    AppModelPolicy_Type_ImplicitPackageBreakaway = $B,
    AppModelPolicy_Type_ProcessActivationShim = $C,
    AppModelPolicy_Type_AppKnownToStateRepository = $D,
    AppModelPolicy_Type_AudioManagement = $E,
    AppModelPolicy_Type_PackageMayContainPublicCOMRegistrations = $F,
    AppModelPolicy_Type_PackageMayContainPrivateCOMRegistrations = $10,
    AppModelPolicy_Type_LaunchCreateProcessExtensions = $11,
    AppModelPolicy_Type_CLRCompat = $12,
    AppModelPolicy_Type_LoaderIgnoreAlteredSearchForRelativePath = $13,
    AppModelPolicy_Type_ImplicitlyActivateClassicAAAServersAsIU = $14,
    AppModelPolicy_Type_COMClassicCatalog = $15,
    AppModelPolicy_Type_COMUnmarshaling = $16,
    AppModelPolicy_Type_COMAppLaunchPerfEnhancements = $17,
    AppModelPolicy_Type_COMSecurityInitialization = $18,
    AppModelPolicy_Type_ROInitializeSingleThreadedBehavior = $19,
    AppModelPolicy_Type_COMDefaultExceptionHandling = $1A,
    AppModelPolicy_Type_COMOopProxyAgility = $1B,
    AppModelPolicy_Type_AppServiceLifetime = $1C,
    AppModelPolicy_Type_WebPlatform = $1D,
    AppModelPolicy_Type_WinInetStoragePartitioning = $1E,
    AppModelPolicy_Type_IndexerProtocolHandlerHost = $1F,                     // Win 10 RS2+
    AppModelPolicy_Type_LoaderIncludeUserDirectories = $20,                   // Win 10 RS2+
    AppModelPolicy_Type_ConvertAppContainerToRestrictedAppContainer = $21,    // Win 10 RS2+
    AppModelPolicy_Type_PackageMayContainPrivateMapiProvider = $22,           // Win 10 RS2+
    AppModelPolicy_Type_AdminProcessPackageClaims = $23,                      // Win 10 RS3+
    AppModelPolicy_Type_RegistryRedirectionBehavior = $24,                    // Win 10 RS3+
    AppModelPolicy_Type_BypassCreateProcessAppxExtension = $25,               // Win 10 RS3+
    AppModelPolicy_Type_KnownFolderRedirection = $26,                         // Win 10 RS3+
    AppModelPolicy_Type_PrivateActivateAsPackageWinrtClasses = $27,           // Win 10 RS3+
    AppModelPolicy_Type_AppPrivateFolderRedirection = $28,                    // Win 10 RS3+
    AppModelPolicy_Type_GlobalSystemAppdataAccess = $29,                      // Win 10 RS3+
    AppModelPolicy_Type_ConsoleHandleInheritance = $2A,                       // Win 10 RS4+
    AppModelPolicy_Type_ConsoleBufferAccess = $2B,                            // Win 10 RS4+
    AppModelPolicy_Type_ConvertCallerTokenToUserTokenForDeployment = $2C,     // Win 10 RS4+
    AppModelPolicy_Type_ShellExecuteRetrieveIdentityFromCurrentProcess = $2D, // Win 10 RS5+
    AppModelPolicy_Type_CodeIntegritySigning = $2E,                           // Win 10 19H1+
    AppModelPolicy_Type_PTCActivation = $2F,                                  // Win 10 19H1+
    AppModelPolicy_Type_COMIntraPackageRPCCall = $30,                         // Win 10 20H1+
    AppModelPolicy_Type_LoadUser32ShimOnWindowsCoreOS = $31,                  // Win 10 20H1+
    AppModelPolicy_Type_SecurityCapabilitiesOverride = $32,                   // Win 10 20H1+
    AppModelPolicy_Type_CurrentDirectoryOverride = $33,                       // Win 10 20H1+
    AppModelPolicy_Type_COMTokenMatchingForAAAServers = $34,                  // Win 10 20H1+
    AppModelPolicy_Type_UseOriginalFileNameInTokenFQBNAttribute = $35,        // Win 10 20H1+
    AppModelPolicy_Type_LoaderIncludeAlternateForwarders = $36,               // Win 10 20H1+
    AppModelPolicy_Type_PullPackageDependencyData = $37,                      // Win 10 20H1+
    AppModelPolicy_Type_AppInstancingErrorBehavior = $38,                     // Win 11+
    AppModelPolicy_Type_BackgroundTaskRegistrationType = $39,                 // Win 11+
    AppModelPolicy_Type_ModsPowerNotifification = $3A                         // Win 11+
  );

  // private - includes both type and value as 0xTTTTVVVV
  [MinOSVersion(OsWin10RS1)]
  [SDKName('AppModelPolicy_PolicyValue')]
  TAppModelPolicyValue = type Cardinal;

  // Info class 0x1
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_LifecycleManager_')]
  TAppModelPolicy_LifecycleManager = (
    AppModelPolicy_LifecycleManager_Unmanaged = 0,
    AppModelPolicy_LifecycleManager_ManagedByPLM = 1,
    AppModelPolicy_LifecycleManager_ManagedByEM = 2
  );

  // Info class 0x2
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_AppdataAccess_')]
  TAppModelPolicy_AppdataAccess = (
    AppModelPolicy_AppdataAccess_Allowed = 0,
    AppModelPolicy_AppdataAccess_Denied = 1
  );

  // Info class 0x3
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_WindowingModel_')]
  TAppModelPolicy_WindowingModel = (
    AppModelPolicy_WindowingModel_HWND = 0,
    AppModelPolicy_WindowingModel_CoreWindow = 1,
    AppModelPolicy_WindowingModel_LegacyPhone = 2,
    AppModelPolicy_WindowingModel_None = 3
  );

  // Info class 0x4
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_DLLSearchOrder_')]
  TAppModelPolicy_DLLSearchOrder = (
    AppModelPolicy_DLLSearchOrder_Traditional = 0,
    AppModelPolicy_DLLSearchOrder_PackageGraphBased = 1
  );

  // Info class 0x5
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_Fusion_')]
  TAppModelPolicy_Fusion = (
    AppModelPolicy_Fusion_Full = 0,
    AppModelPolicy_Fusion_Limited = 1
  );

  // Info class 0x6
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_NonWindowsCodecLoading_')]
  TAppModelPolicy_NonWindowsCodecLoading = (
    AppModelPolicy_NonWindowsCodecLoading_Allowed = 0,
    AppModelPolicy_NonWindowsCodecLoading_Denied = 1
  );

  // Info class 0x7
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ProcessEnd_')]
  TAppModelPolicy_ProcessEnd = (
    AppModelPolicy_ProcessEnd_TerminateProcess = 0,
    AppModelPolicy_ProcessEnd_ExitProcess = 1
  );

  // Info class 0x8
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_BeginThreadInit_')]
  TAppModelPolicy_BeginThreadInit = (
    AppModelPolicy_BeginThreadInit_ROInitialize = 0,
    AppModelPolicy_BeginThreadInit_None = 1
  );

  // Info class 0x9
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_DeveloperInformation_')]
  TAppModelPolicy_DeveloperInformation = (
    AppModelPolicy_DeveloperInformation_UI = 0,
    AppModelPolicy_DeveloperInformation_None = 1
  );

  // Info class 0xA
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_CreateFileAccess_')]
  TAppModelPolicy_CreateFileAccess = (
    AppModelPolicy_CreateFileAccess_Full = 0,
    AppModelPolicy_CreateFileAccess_Limited = 1
  );

  // Info class 0xB
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ImplicitPackageBreakaway_')]
  TAppModelPolicy_ImplicitPackageBreakaway = (
    AppModelPolicy_ImplicitPackageBreakaway_Allowed = 0,
    AppModelPolicy_ImplicitPackageBreakaway_Denied = 1,
    AppModelPolicy_ImplicitPackageBreakaway_DeniedByApp = 2 // Win 10 RS2+
  );

  // Info class 0xC
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ProcessActivationShim_')]
  TAppModelPolicy_ProcessActivationShim = (
    AppModelPolicy_ProcessActivationShim_None = 0,
    AppModelPolicy_ProcessActivationShim_PackagedCWALauncher = 1
  );

  // Info class 0xD
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_AppKnownToStateRepository_')]
  TAppModelPolicy_AppKnownToStateRepository = (
    AppModelPolicy_AppKnownToStateRepository_Known = 0,
    AppModelPolicy_AppKnownToStateRepository_Unknown = 1
  );

  // Info class 0xE
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_AudioManagement_')]
  TAppModelPolicy_AudioManagement = (
    AppModelPolicy_AudioManagement_Unmanaged = 0,
    AppModelPolicy_AudioManagement_ManagedByPBM = 1
  );

  // Info class 0xF
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_PackageMayContainPublicCOMRegistrations_')]
  TAppModelPolicy_PackageMayContainPublicCOMRegistrations = (
    AppModelPolicy_PackageMayContainPublicCOMRegistrations_Yes = 0,
    AppModelPolicy_PackageMayContainPublicCOMRegistrations_No = 1
  );

  // Info class 0x10
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_PackageMayContainPrivateCOMRegistrations_')]
  TAppModelPolicy_PackageMayContainPrivateCOMRegistrations = (
    AppModelPolicy_PackageMayContainPrivateCOMRegistrations_None = 0,
    AppModelPolicy_PackageMayContainPrivateCOMRegistrations_PrivateHive = 1
  );

  // Info class 0x11
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_LaunchCreateProcessExtensions_')]
  TAppModelPolicy_LaunchCreateProcessExtensions = (
    AppModelPolicy_LaunchCreateProcessExtensions_None = 0,
    AppModelPolicy_LaunchCreateProcessExtensions_RegisterWithPSM = 1,
    AppModelPolicy_LaunchCreateProcessExtensions_RegisterWithDesktopAppx = 2,
    AppModelPolicy_LaunchCreateProcessExtensions_RegisterWithDesktopAppxNoHeliumContainer = 3 // Win 10 20H1+
  );

  // Info class 0x12
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_CLRCompat_')]
  TAppModelPolicy_CLRCompat = (
    AppModelPolicy_CLRCompat_Others = 0,
    AppModelPolicy_CLRCompat_ClassicDesktop = 1,
    AppModelPolicy_CLRCompat_Universal = 2,
    AppModelPolicy_CLRCompat_PackagedDesktop = 3
  );

  // Info class 0x13
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_LoaderIgnoreAlteredSearchForRelativePath_')]
  TAppModelPolicy_LoaderIgnoreAlteredSearchForRelativePath = (
    AppModelPolicy_LoaderIgnoreAlteredSearchForRelativePath_False = 0,
    AppModelPolicy_LoaderIgnoreAlteredSearchForRelativePath_True = 1
  );

  // Info class 0x14
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ImplicitlyActivateClassicAAAServersAsIU_')]
  TAppModelPolicy_ImplicitlyActivateClassicAAAServersAsIU = (
    AppModelPolicy_ImplicitlyActivateClassicAAAServersAsIU_Yes = 0,
    AppModelPolicy_ImplicitlyActivateClassicAAAServersAsIU_No = 1
  );

  // Info class 0x15
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_COMClassicCatalog_')]
  TAppModelPolicy_COMClassicCatalog = (
    AppModelPolicy_COMClassicCatalog_MachineHiveAndUserHive = 0,
    AppModelPolicy_COMClassicCatalog_MachineHiveOnly = 1
  );

  // Info class 0x16
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_COMUnmarshaling_')]
  TAppModelPolicy_COMUnmarshaling = (
    AppModelPolicy_COMUnmarshaling_ForceStrongUnmarshaling = 0,
    AppModelPolicy_COMUnmarshaling_ApplicationManaged = 1
  );

  // Info class 0x17
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_COMAppLaunchPerfEnhancements_')]
  TAppModelPolicy_COMAppLaunchPerfEnhancements = (
    AppModelPolicy_COMAppLaunchPerfEnhancements_Enabled = 0,
    AppModelPolicy_COMAppLaunchPerfEnhancements_Disabled = 1
  );

  // Info class 0x18
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_COMSecurityInitialization_')]
  TAppModelPolicy_COMSecurityInitialization = (
    AppModelPolicy_COMSecurityInitialization_ApplicationManaged = 0,
    AppModelPolicy_COMSecurityInitialization_SystemManaged = 1
  );

  // Info class 0x19
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ROInitializeSingleThreadedBehavior_')]
  TAppModelPolicy_ROInitializeSingleThreadedBehavior = (
    AppModelPolicy_ROInitializeSingleThreadedBehavior_ASTA = 0,
    AppModelPolicy_ROInitializeSingleThreadedBehavior_STA = 1
  );

  // Info class 0x1A
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_COMDefaultExceptionHandling_')]
  TAppModelPolicy_COMDefaultExceptionHandling = (
    AppModelPolicy_COMDefaultExceptionHandling_HandleAll = 0,
    AppModelPolicy_COMDefaultExceptionHandling_HandleNone = 1
  );

  // Info class 0x1B
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_COMOopProxyAgility_')]
  TAppModelPolicy_COMOopProxyAgility = (
    AppModelPolicy_COMOopProxyAgility_Agile = 0,
    AppModelPolicy_COMOopProxyAgility_NonAgile = 1
  );

  // Info class 0x1C
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_AppServiceLifetime_')]
  TAppModelPolicy_AppServiceLifetime = (
    AppModelPolicy_AppServiceLifetime_StandardTimeout = 0,
    AppModelPolicy_AppServiceLifetime_ExtensibleTimeout = 1,     // Win RS5+
    AppModelPolicy_AppServiceLifetime_ExtendedForSamePackage = 2 // Had diff value before Win 10 RS5
  );

  // Info class 0x1D
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_WebPlatform_')]
  TAppModelPolicy_WebPlatform = (
    AppModelPolicy_WebPlatform_Edge = 0,
    AppModelPolicy_WebPlatform_Legacy = 1
  );

  // Info class 0x1E
  [MinOSVersion(OsWin10RS1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_WinInetStoragePartitioning_')]
  TAppModelPolicy_WinInetStoragePartitioning = (
    AppModelPolicy_WinInetStoragePartitioning_Isolated = 0,
    AppModelPolicy_WinInetStoragePartitioning_SharedWithAppContainer = 1
  );

  // Info class 0x1F
  [MinOSVersion(OsWin10RS2)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_IndexerProtocolHandlerHost_')]
  TAppModelPolicy_IndexerProtocolHandlerHost = (
    AppModelPolicy_IndexerProtocolHandlerHost_PerUser = 0,
    AppModelPolicy_IndexerProtocolHandlerHost_PerApp = 1
  );

  // Info class 0x20
  [MinOSVersion(OsWin10RS2)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_LoaderIncludeUserDirectories_')]
  TAppModelPolicy_LoaderIncludeUserDirectories = (
    AppModelPolicy_LoaderIncludeUserDirectories_False = 0,
    AppModelPolicy_LoaderIncludeUserDirectories_True = 1
  );

  // Info class 0x21
  [MinOSVersion(OsWin10RS2)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ConvertAppContainerToRestrictedAppContainer_')]
  TAppModelPolicy_ConvertAppContainerToRestrictedAppContainer = (
    AppModelPolicy_ConvertAppContainerToRestrictedAppContainer_False = 0,
    AppModelPolicy_ConvertAppContainerToRestrictedAppContainer_True = 1
  );

  // Info class 0x22
  [MinOSVersion(OsWin10RS2)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_PackageMayContainPrivateMapiProvider_')]
  TAppModelPolicy_PackageMayContainPrivateMapiProvider = (
    AppModelPolicy_PackageMayContainPrivateMapiProvider_None = 0,
    AppModelPolicy_PackageMayContainPrivateMapiProvider_PrivateHive = 1
  );

  // Info class 0x23
  [MinOSVersion(OsWin10RS3)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_AdminProcessPackageClaims_')]
  TAppModelPolicy_AdminProcessPackageClaims = (
    AppModelPolicy_AdminProcessPackageClaims_None = 0,
    AppModelPolicy_AdminProcessPackageClaims_Caller = 1
  );

  // Info class 0x24
  [MinOSVersion(OsWin10RS3)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_RegistryRedirectionBehavior_')]
  TAppModelPolicy_RegistryRedirectionBehavior = (
    AppModelPolicy_RegistryRedirectionBehavior_None = 0,
    AppModelPolicy_RegistryRedirectionBehavior_CopyOnWrite = 1
  );

  // Info class 0x25
  [MinOSVersion(OsWin10RS3)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_BypassCreateProcessAppxExtension_')]
  TAppModelPolicy_BypassCreateProcessAppxExtension = (
    AppModelPolicy_BypassCreateProcessAppxExtension_False = 0,
    AppModelPolicy_BypassCreateProcessAppxExtension_True = 1
  );

  // Info class 0x26
  [MinOSVersion(OsWin10RS3)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_KnownFolderRedirection_')]
  TAppModelPolicy_KnownFolderRedirection = (
    AppModelPolicy_KnownFolderRedirection_Isolated = 0,
    AppModelPolicy_KnownFolderRedirection_RedirectToPackage = 1
  );

  // Info class 0x27
  [MinOSVersion(OsWin10RS3)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_PrivateActivateAsPackageWinrtClasses_')]
  TAppModelPolicy_PrivateActivateAsPackageWinrtClasses = (
    AppModelPolicy_PrivateActivateAsPackageWinrtClasses_AllowNone = 0,
    AppModelPolicy_PrivateActivateAsPackageWinrtClasses_AllowFullTrust = 1,
    AppModelPolicy_PrivateActivateAsPackageWinrtClasses_AllowNonFullTrust = 2
  );

  // Info class 0x28
  [MinOSVersion(OsWin10RS3)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_AppPrivateFolderRedirection_')]
  TAppModelPolicy_AppPrivateFolderRedirection = (
    AppModelPolicy_AppPrivateFolderRedirection_None = 0,
    AppModelPolicy_AppPrivateFolderRedirection_AppPrivate = 1
  );

  // Info class 0x29
  [MinOSVersion(OsWin10RS3)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_GlobalSystemAppdataAccess_')]
  TAppModelPolicy_GlobalSystemAppdataAccess = (
    AppModelPolicy_GlobalSystemAppdataAccess_Normal = 0,
    AppModelPolicy_GlobalSystemAppdataAccess_Virtualized = 1
  );

  // Info class 0x2A
  [MinOSVersion(OsWin10RS4)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ConsoleHandleInheritance_')]
  TAppModelPolicy_ConsoleHandleInheritance = (
    AppModelPolicy_ConsoleHandleInheritance_ConsoleOnly = 0,
    AppModelPolicy_ConsoleHandleInheritance_All = 1
  );

  // Info class 0x2B
  [MinOSVersion(OsWin10RS4)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ConsoleBufferAccess_')]
  TAppModelPolicy_ConsoleBufferAccess = (
    AppModelPolicy_ConsoleBufferAccess_RestrictedUnidirectional = 0,
    AppModelPolicy_ConsoleBufferAccess_Unrestricted = 1
  );

  // Info class 0x2C
  [MinOSVersion(OsWin10RS4)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ConvertCallerTokenToUserTokenForDeployment_')]
  TAppModelPolicy_ConvertCallerTokenToUserTokenForDeployment = (
    AppModelPolicy_ConvertCallerTokenToUserTokenForDeployment_UserCallerToken = 0,
    AppModelPolicy_ConvertCallerTokenToUserTokenForDeployment_ConvertTokenToUserToken = 1
  );

  // Info class 0x2D
  [MinOSVersion(OsWin10RS5)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ShellExecuteRetrieveIdentityFromCurrentProcess_')]
  TAppModelPolicy_ShellExecuteRetrieveIdentityFromCurrentProcess = (
    AppModelPolicy_ShellExecuteRetrieveIdentityFromCurrentProcess_False = 0,
    AppModelPolicy_ShellExecuteRetrieveIdentityFromCurrentProcess_True = 1
  );

  // Info class 0x2E
  [MinOSVersion(OsWin1019H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_CodeIntegritySigning_')]
  TAppModelPolicy_CodeIntegritySigning = (
    AppModelPolicy_CodeIntegritySigning_Default = 0,
    AppModelPolicy_CodeIntegritySigning_OriginBased = 1,
    AppModelPolicy_CodeIntegritySigning_OriginBasedForDev = 2
  );

  // Info class 0x2F
  [MinOSVersion(OsWin1019H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_PTCActivation_')]
  TAppModelPolicy_PTCActivation = (
    AppModelPolicy_PTCActivation_Default = 0,
    AppModelPolicy_PTCActivation_AllowActivationInBrokerForMediumILContainer = 1
  );

  // Info class 0x30
  [MinOSVersion(OsWin1020H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_COMIntraPackageRPCCall_')]
  TAppModelPolicy_COMIntraPackageRPCCall = (
    AppModelPolicy_COMIntraPackageRPCCall_NoWake = 0,
    AppModelPolicy_COMIntraPackageRPCCall_Wake = 1
  );

  // Info class 0x31
  [MinOSVersion(OsWin1020H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_LoadUser32ShimOnWindowsCoreOS_')]
  TAppModelPolicy_LoadUser32ShimOnWindowsCoreOS = (
    AppModelPolicy_LoadUser32ShimOnWindowsCoreOS_True = 0,
    AppModelPolicy_LoadUser32ShimOnWindowsCoreOS_False = 1
  );

  // Info class 0x32
  [MinOSVersion(OsWin1020H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_SecurityCapabilitiesOverride_')]
  TAppModelPolicy_SecurityCapabilitiesOverride = (
    AppModelPolicy_SecurityCapabilitiesOverride_None = 0,
    AppModelPolicy_SecurityCapabilitiesOverride_PackageCapabilities = 1
  );

  // Info class 0x33
  [MinOSVersion(OsWin1020H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_CurrentDirectoryOverride_')]
  TAppModelPolicy_CurrentDirectoryOverride = (
    AppModelPolicy_CurrentDirectoryOverride_None = 0,
    AppModelPolicy_CurrentDirectoryOverride_PackageInstallDirectory = 1
  );

  // Info class 0x34
  [MinOSVersion(OsWin1020H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_COMTokenMatchingForAAAServers_')]
  TAppModelPolicy_COMTokenMatchingForAAAServers = (
    AppModelPolicy_COMTokenMatchingForAAAServers_DontUseNtCompareTokens = 0,
    AppModelPolicy_COMTokenMatchingForAAAServers_UseNtCompareTokens = 1
  );

  // Info class 0x35
  [MinOSVersion(OsWin1020H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_UseOriginalFileNameInTokenFQBNAttribute_')]
  TAppModelPolicy_UseOriginalFileNameInTokenFQBNAttribute = (
    AppModelPolicy_UseOriginalFileNameInTokenFQBNAttribute_False = 0,
    AppModelPolicy_UseOriginalFileNameInTokenFQBNAttribute_True = 1
  );

  // Info class 0x36
  [MinOSVersion(OsWin1020H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_LoaderIncludeAlternateForwarders_')]
  TAppModelPolicy_LoaderIncludeAlternateForwarders = (
    AppModelPolicy_LoaderIncludeAlternateForwarders_False = 0,
    AppModelPolicy_LoaderIncludeAlternateForwarders_True = 1
  );

  // Info class 0x37
  [MinOSVersion(OsWin1020H1)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_PullPackageDependencyData_')]
  TAppModelPolicy_PullPackageDependencyData = (
    AppModelPolicy_PullPackageDependencyData_False = 0,
    AppModelPolicy_PullPackageDependencyData_True = 1
  );


  // Info class 0x38
  [MinOSVersion(OsWin11)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_AppInstancingErrorBehavior_')]
  TAppModelPolicy_AppInstancingErrorBehavior = (
    AppModelPolicy_AppInstancingErrorBehavior_SuppressErrors = 0,
    AppModelPolicy_AppInstancingErrorBehavior_RaiseErrors = 1
  );

  // Info class 0x39
  [MinOSVersion(OsWin11)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_BackgroundTaskRegistrationType_')]
  TAppModelPolicy_BackgroundTaskRegistrationType = (
    AppModelPolicy_BackgroundTaskRegistrationType_Unsupported = 0,
    AppModelPolicy_BackgroundTaskRegistrationType_Manifested = 1,
    AppModelPolicy_BackgroundTaskRegistrationType_Win32CLSID = 2
  );

  // Info class 0x3A
  [MinOSVersion(OsWin11)]
  [NamingStyle(nsCamelCase, 'AppModelPolicy_ModsPowerNotifification_')]
  TAppModelPolicy_ModsPowerNotifification = (
    AppModelPolicy_ModsPowerNotifification_Disabled = 0,
    AppModelPolicy_ModsPowerNotifification_Enabled = 1
  );

  { AppX Activation }

  [SDKName('DESKTOPAPPXACTIVATEOPTIONS')]
  [FlagName(DAXAO_ELEVATE, 'Elavate')]
  [FlagName(DAXAO_NONPACKAGED_EXE, 'Non-packaged EXE')]
  [FlagName(DAXAO_NONPACKAGED_EXE_PROCESS_TREE, 'Non-packaged EXE Process Tree')]
  [FlagName(DAXAO_NO_ERROR_UI, 'No Error UI')]
  [FlagName(DAXAO_CHECK_FOR_APPINSTALLER_UPDATES, 'Check For AppInstaller Updates')]
  [FlagName(DAXAO_CENTENNIAL_PROCESS, 'Centennial Process')]
  [FlagName(DAXAO_UNIVERSAL_PROCESS, 'Universal Process')]
  [FlagName(DAXAO_WIN32ALACARTE_PROCESS, 'Win32Alacarte Process')]
  [FlagName(DAXAO_PARTIAL_TRUST, 'Partial Trust')]
  [FlagName(DAXAO_UNIVERSAL_CONSOLE, 'Universal Console')]
  TDesktopAppxActivateOptions = type Cardinal;

  [MinOSVersion(OsWin10RS1)]
  [SDKName('IDesktopAppXActivator')]
  IDesktopAppXActivatorV1 = interface (IUnknown)
    ['{B81F98D4-6F57-401A-8FCC-B66014CA80BB}']

    function Activate(
      [in] applicationUserModelId: PWideChar;
      [in] packageRelativeExecutable: PWideChar;
      [in, opt] arguments: PWideChar;
      [out, ReleaseWith('NtClose')] out processHandle: THandle32
    ): HResult; stdcall;

    function ActivateWithOptions(
      [in] applicationUserModelId: PWideChar;
      [in] executable: PWideChar;
      [in, opt] arguments: PWideChar;
      [in] activationOptions: TDesktopAppxActivateOptions;
      [out, ReleaseWith('NtClose')] out processHandle: THandle32
    ): HResult; stdcall;
  end;

  [MinOSVersion(OsWin10RS2)]
  [SDKName('IDesktopAppXActivator')]
  IDesktopAppXActivatorV2 = interface (IUnknown)
    ['{72E3A5B0-8FEA-485C-9F8B-822B16DBA17F}']

    function Activate(
      [in] applicationUserModelId: PWideChar;
      [in] packageRelativeExecutable: PWideChar;
      [in, opt] arguments: PWideChar;
      [out, ReleaseWith('NtClose')] out processHandle: THandle32
    ): HResult; stdcall;

    function ActivateWithOptions(
      [in] applicationUserModelId: PWideChar;
      [in] executable: PWideChar;
      [in, opt] arguments: PWideChar;
      [in] activationOptions: TDesktopAppxActivateOptions;
      [in, opt] parentProcessId: TProcessId32;
      [out, ReleaseWith('NtClose')] out processHandle: THandle32
    ): HResult; stdcall;
  end;

  [MinOSVersion(OsWin11)]
  [SDKName('IDesktopAppXActivator')]
  IDesktopAppXActivatorV3 = interface (IUnknown)
    ['{F158268A-D5A5-45CE-99CF-00D6C3F3FC0A}']

    function Activate(
      [in] applicationUserModelId: PWideChar;
      [in] packageRelativeExecutable: PWideChar;
      [in, opt] arguments: PWideChar;
      [out, ReleaseWith('NtClose')] out processHandle: THandle32
    ): HResult; stdcall;

    function ActivateWithOptions(
      [in] applicationUserModelId: PWideChar;
      [in] executable: PWideChar;
      [in, opt] arguments: PWideChar;
      [in] activationOptions: TDesktopAppxActivateOptions;
      [in, opt] parentProcessId: TProcessId32;
      [out, ReleaseWith('NtClose')] out processHandle: THandle32
    ): HResult; stdcall;

    function ActivateWithOptionsAndArgs(
      [in] applicationUserModelId: PWideChar;
      [in] executable: PWideChar;
      [in, opt] arguments: PWideChar;
      [in] activationOptions: TDesktopAppxActivateOptions;
      [in, opt] parentProcessId: TProcessId32;
      [in, opt] activatedEventArgs: IInterface;
      [out, ReleaseWith('NtClose')] out processHandle: THandle32
    ): HResult; stdcall;

    function ActivateWithOptionsArgsWorkingDirectoryShowWindow(
      [in] applicationUserModelId: PWideChar;
      [in] executable: PWideChar;
      [in, opt] arguments: PWideChar;
      [in] activationOptions: TDesktopAppxActivateOptions;
      [in, opt] parentProcessId: TProcessId32;
      [in, opt] activatedEventArgs: IInterface;
      [in, opt] workingDirectory: PWideChar;
      [in] showWindow: TShowMode32;
      [out, ReleaseWith('NtClose')] out processHandle: THandle32
    ): HResult; stdcall;
  end;

// SDK::appmodel.h
[MinOSVersion(OsWin81)]
function GetPackagePath(
  [in] const packageId: TPackageId;
  [Reserved] reserved: Cardinal;
  [in, out, NumberOfElements] var pathLength: Cardinal;
  [out, WritesTo] path: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin81)]
function GetPackagePathByFullName(
  [in] packageFullName: PWideChar;
  [in, out, NumberOfElements] var pathLength: Cardinal;
  [out, WritesTo] path: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin81)]
function GetStagedPackagePathByFullName(
  [in] packageFullName: PWideChar;
  [in, out, NumberOfElements] var pathLength: Cardinal;
  [out, WritesTo] path: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin1019H1)]
function GetPackagePathByFullName2(
  [in] packageFullName: PWideChar;
  [in] packagePathType: TPackagePathType;
  [in, out, NumberOfElements] var pathLength: Cardinal;
  [out, WritesTo] path: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin1019H1)]
function GetStagedPackagePathByFullName2(
  [in] packageFullName: PWideChar;
  [in] packagePathType: TPackagePathType;
  [in, out, NumberOfElements] var pathLength: Cardinal;
  [out, WritesTo] path: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin10TH1)]
function GetApplicationUserModelIdFromToken(
  [in, Access(TOKEN_QUERY)] token: THandle;
  [in, out, NumberOfElements] var applicationUserModelIdLength: Cardinal;
  [out, WritesTo] applicationUserModelId: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function PackageIdFromFullName(
  [in] packageFullName: PWideChar;
  [in] flags: TPackageInformationFlags;
  [in, out, NumberOfBytes] var bufferLength: Cardinal;
  [out, WritesTo] buffer: PPackageId
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function PackageFullNameFromId(
  [in] const packageId: TPackageId;
  [in, out, NumberOfElements] var packageFullNameLength: Cardinal;
  [out, WritesTo] packageFullName: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function PackageFamilyNameFromId(
  [in] const packageId: TPackageId;
  [in, out, NumberOfElements] var packageFamilyNameLength: Cardinal;
  [out, WritesTo] packageFamilyName: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function PackageFamilyNameFromFullName(
  [in] packageFullName: PWideChar;
  [in, out, NumberOfElements] var packageFamilyNameLength: Cardinal;
  [out, WritesTo] packageFamilyName: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function PackageNameAndPublisherIdFromFamilyName(
  [in] packageFamilyName: PWideChar;
  [in, out, NumberOfElements] var packageNameLength: Cardinal;
  [out, WritesTo] packageName: PWideChar;
  [in, out, NumberOfElements] var packagePublisherIdLength: Cardinal;
  [out, WritesTo] packagePublisherId: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin81)]
function FormatApplicationUserModelId(
  [in] packageFamilyName: PWideChar;
  [in] packageRelativeApplicationId: PWideChar;
  [in, out, NumberOfElements] var applicationUserModelIdLength: Cardinal;
  [out, WritesTo] applicationUserModelId: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin81)]
function ParseApplicationUserModelId(
  [in] applicationUserModelId: PWideChar;
  [in, out, NumberOfElements] var packageFamilyNameLength: Cardinal;
  [out, WritesTo] packageFamilyName: PWideChar;
  [in, out, NumberOfElements] var packageRelativeApplicationIdLength: Cardinal;
  [out, WritesTo] packageRelativeApplicationId: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function GetPackagesByPackageFamily(
  [in] packageFamilyName: PWideChar;
  [in, out, NumberOfElements] var count: Cardinal;
  [out, WritesTo] packageFullNames: PPackageFullNames;
  [in, out, NumberOfElements] var bufferLength: Cardinal;
  [out, WritesTo] buffer: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin81)]
function FindPackagesByPackageFamily(
  [in] packageFamilyName: PWideChar;
  [in] packageFilters: TPackageFilters;
  [in, out, NumberOfElements] var count: Cardinal;
  [out, WritesTo] packageFullNames: PPackageFullNames;
  [in, out, NumberOfElements] var bufferLength: Cardinal;
  [out, WritesTo] buffer: PWideChar;
  [out, WritesTo] packageProperties: PPackagePropertiesArray
): TWin32Error; stdcall; external kernelbase delayed;

// PHNT::ntrtl.h
[MinOSVersion(OsWin10TH1)]
function RtlQueryPackageClaims(
  [in, Access(TOKEN_QUERY)] TokenHandle: THandle;
  [out, opt, WritesTo] PackageFullName: PWideChar;
  [in, out, opt, NumberOfBytes] PackageSize: PNativeUInt;
  [out, opt, WritesTo] AppId: PWideChar;
  [in, out, opt, NumberOfBytes] AppIdSize: PNativeUInt;
  [out, opt] DynamicId: PGuid;
  [out, opt] PkgClaim: PPsPkgClaim;
  [out, opt] AttributesPresent: PPackagePresentAttributes
): NTSTATUS; stdcall; external ntdll delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin81)]
function GetStagedPackageOrigin(
  [in] packageFullName: PWideChar;
  [out] out origin: TPackageOrigin
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function OpenPackageInfoByFullName(
  [in] packageFullName: PWideChar;
  [Reserved] reserved: Cardinal;
  [out, ReleaseWith('ClosePackageInfo')]
    out packageInfoReference: TPackageInfoReference
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin10TH1)]
function OpenPackageInfoByFullNameForUser(
  [in, opt] userSid: PSid;
  [in] packageFullName: PWideChar;
  [Reserved] reserved: Cardinal;
  [out, ReleaseWith('ClosePackageInfo')]
    out packageInfoReference: TPackageInfoReference
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function ClosePackageInfo(
  [in] packageInfoReference: TPackageInfoReference
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin8)]
function GetPackageInfo(
  [in] packageInfoReference: TPackageInfoReference;
  [in] flags: TPackageFilters;
  [in, out, NumberOfBytes] var bufferLength: Cardinal;
  [out, opt, WritesTo] buffer: PPackageInfoArray;
  [out, opt] count: PCardinal
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin1019H1)]
function GetPackageInfo2(
  [in] packageInfoReference: TPackageInfoReference;
  [in] flags: TPackageFilters;
  [in] packagePathType: TPackagePathType;
  [in, out, NumberOfBytes] var bufferLength: Cardinal;
  [out, opt, WritesTo] buffer: PPackageInfoArray;
  [out, opt] count: PCardinal
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin81)]
function GetPackageApplicationIds(
  [in] packageInfoReference: TPackageInfoReference;
  [in, out] var bufferLength: Cardinal;
  [out, WritesTo] buffer: PAppIdArray;
  [out, opt] count: PCardinal
): TWin32Error; stdcall; external kernelbase delayed;

// SDK::appmodel.h
[MinOSVersion(OsWin1021H1)]
function CheckIsMSIXPackage(
  [in] packageFullName: PWideChar;
  [out] out isMSIXPackage: LongBool
): HRESULT; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageInstallTime(
  [in] packageFullName: PWideChar;
  [out] out InstallTime: TLargeInteger
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin1020H1)]
function PublisherFromPackageFullName(
  [in] FullName: PWideChar;
  [in, out, NumberOfElements] var BufferSize: Cardinal;
  [out, WritesTo] Buffer: PWideChar
): HResult; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin10TH1)]
function PackageSidFromFamilyName(
  [in] FamilyName: PWideChar;
  [out, ReleaseWith('RtlFreeSid')] out Sid: PSid
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin10TH1)]
function PackageSidFromProductId(
  [in] PackageInfoReference: TPackageInfoReference;
  [out, ReleaseWith('RtlFreeSid')] out Sid: PSid
): HResult; stdcall; external kernelbase delayed;

// Appx functions

// rev
[MinOSVersion(OsWin81)]
procedure AppXFreeMemory(
  [in] Buffer: Pointer
); stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function AppXGetOSMaxVersionTested(
  [in] PackageFullName: PWideChar;
  [out] out OSMaxVersionTested: TPackageVersion
): HRESULT; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function AppXGetDevelopmentMode(
  [in] PackageFullName: PWideChar;
  [out] out DevelopmentMode: LongBool
): HRESULT; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function AppXGetPackageSid(
  [in] PackageFullName: PWideChar;
  [out, ReleaseWith('AppXFreeMemory')] out Sid: PSid
): HRESULT; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function AppXGetPackageCapabilities(
  [in] PackageFullName: PWideChar;
  [out] out IsFullTrust: LongBool;
  [out, ReleaseWith('AppXFreeMemory')] out Capabilities: PSidAndAttributesArray;
  [out] out Count: Cardinal
): HRESULT; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function AppXLookupDisplayName(
  [in] PackageSid: PSid;
  [out, ReleaseWith('AppXFreeMemory')] out DisplayName: PWideChar
): HRESULT; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function AppXLookupMoniker(
  [in] PackageSid: PSid;
  [out, ReleaseWith('AppXFreeMemory')] out Moniker: PWideChar
): HRESULT; stdcall; external kernelbase delayed;

// Package Properties

// rev
[MinOSVersion(OsWin81)]
function GetCurrentPackageContext(
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageContext: PPackageContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageContext(
  [in] PackageInfoReference: TPackageInfoReference;
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageContext: PPackageContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageProperty(
  [in] PackageContext: PPackageContextReference;
  [in] PropertyId: TPackageProperty;
  [in, out, NumberOfBytes] var BufferLength: Cardinal;
  [out, WritesTo] Buffer: Pointer
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackagePropertyString(
  [in] PackageContext: PPackageContextReference;
  [in] PropertyId: TPackageProperty;
  [in, out, NumberOfElements] var BufferLength: Cardinal;
  [out, WritesTo] Buffer: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageOSMaxVersionTested(
  [in] PackageContext: PPackageContextReference;
  [out] out OSMaxVersionTested: TPackageVersion
): TWin32Error; stdcall; external kernelbase delayed;

// Package Application Properties

// rev
[MinOSVersion(OsWin81)]
function GetCurrentPackageApplicationContext(
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageApplicationContext: PPackageApplicationContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageApplicationContext(
  [in] PackageInfoReference: TPackageInfoReference;
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageApplicationContext: PPackageApplicationContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageApplicationProperty(
  [in] PackageApplicationContext: PPackageApplicationContextReference;
  [in] PropertyId: TPackageApplicationProperty;
  [in, out, NumberOfBytes] var BufferLength: Cardinal;
  [out, WritesTo] Buffer: Pointer
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageApplicationPropertyString(
  [in] PackageApplicationContext: PPackageApplicationContextReference;
  [in] PropertyId: TPackageApplicationProperty;
  [in, out, NumberOfElements] var BufferLength: Cardinal;
  [out, WritesTo] Buffer: PWideChar
): TWin32Error; stdcall; external kernelbase delayed;

// Package Resource Properties

// rev
[MinOSVersion(OsWin81)]
function GetCurrentPackageResourcesContext(
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageResourcesContext: PPackageResourcesContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageResourcesContext(
  [in] PackageInfoReference: TPackageInfoReference;
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageResourcesContext: PPackageResourcesContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetCurrentPackageApplicationResourcesContext(
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageResourcesContext: PPackageResourcesContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageApplicationResourcesContext(
  [in] PackageInfoReference: TPackageInfoReference;
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageResourcesContext: PPackageResourcesContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageResourcesProperty(
  [in] PackageResourcesContext: PPackageResourcesContextReference;
  [in] PropertyId: TPackageResourcesProperty;
  [in, out, NumberOfBytes] var BufferLength: Cardinal;
  [out, WritesTo] Buffer: Pointer
): TWin32Error; stdcall; external kernelbase delayed;

// Package Security Properties

// rev
[MinOSVersion(OsWin81)]
function GetCurrentPackageSecurityContext(
  [Reserved] Unused: NativeUInt;
  [out] out PackageSecurityContext: PPackageSecurityContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageSecurityContext(
  [in] PackageInfoReference: TPackageInfoReference;
  [Reserved] Unused: NativeUInt;
  [out] out PackageSecurityContext: PPackageSecurityContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin81)]
function GetPackageSecurityProperty(
  [in] PackageSecurityContext: PPackageSecurityContextReference;
  [in] PropertyId: TPackageSecurityProperty;
  [in, out, NumberOfBytes] var BufferLength: Cardinal;
  [out, WritesTo] Buffer: Pointer
): TWin32Error; stdcall; external kernelbase delayed;

// Target Platform Properties

// rev
[MinOSVersion(OsWin10TH1)]
function GetCurrentTargetPlatformContext(
  [Reserved] Unused: NativeUInt;
  [out] out TargetPlatformContext: PTargetPlatformContextReference
): TWin32Error; stdcall; external kernelbase delayed;

[MinOSVersion(OsWin10TH1)]
function GetTargetPlatformContext(
  [in] PackageInfoReference: TPackageInfoReference;
  [Reserved] Unused: NativeUInt;
  [out] out TargetPlatformContext: PTargetPlatformContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin10TH1)]
function GetPackageTargetPlatformProperty(
  [in] TargetPlatformContext: PTargetPlatformContextReference;
  [in] PropertyId: TTargetPlatformProperty;
  [in, out, NumberOfBytes] var BufferLength: Cardinal;
  [out, WritesTo] Buffer: Pointer
): TWin32Error; stdcall; external kernelbase delayed;

// Package Globalization Properties

// rev
[MinOSVersion(OsWin1020H1)]
function GetCurrentPackageGlobalizationContext(
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageGlobalizationContext: PPackageGlobalizationContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin1020H1)]
function GetPackageGlobalizationContext(
  [in] PackageInfoReference: TPackageInfoReference;
  [in] Index: Cardinal;
  [Reserved] Unused: NativeUInt;
  [out] out PackageGlobalizationContext: PPackageGlobalizationContextReference
): TWin32Error; stdcall; external kernelbase delayed;

// rev
[MinOSVersion(OsWin1020H1)]
function GetPackageGlobalizationProperty(
  [in] PackageGlobalizationContext: PPackageGlobalizationContextReference;
  [in] PropertyId: TPackageGlobalizationProperty;
  [in, out, NumberOfBytes] var BufferLength: Cardinal;
  [out, WritesTo] Buffer: Pointer
): TWin32Error; stdcall; external kernelbase delayed;

implementation

{$BOOLEVAL OFF}
{$IFOPT R+}{$DEFINE R+}{$ENDIF}
{$IFOPT Q+}{$DEFINE Q+}{$ENDIF}

end.
