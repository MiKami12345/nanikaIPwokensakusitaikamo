param(
    [Parameter(Mandatory = $true)]
    [string]$InputIP
)

# =====================================
# 定数定義
# =====================================
$CLASS_A_START = [System.Net.IPAddress]::Parse("10.0.0.0").GetAddressBytes()
$CLASS_A_END   = [System.Net.IPAddress]::Parse("10.255.255.255").GetAddressBytes()
$CLASS_B_START = [System.Net.IPAddress]::Parse("172.16.0.0").GetAddressBytes()
$CLASS_B_END   = [System.Net.IPAddress]::Parse("172.31.255.255").GetAddressBytes()
$CLASS_C_START = [System.Net.IPAddress]::Parse("192.168.0.0").GetAddressBytes()
$CLASS_C_END   = [System.Net.IPAddress]::Parse("192.168.255.255").GetAddressBytes()

$CLASS_A_BASE  = "10.0.0.0"
$CLASS_B_BASE  = "172.16.0.0"
$CLASS_C_BASE  = "192.168.0.0"

# =====================================
# 関数群
# =====================================
function Test-ValidIPAddress {
    param([string]$ip)
    if ($ip -match "^(25[0-5]|2[0-4]\d|1?\d{1,2})(\.(25[0-5]|2[0-4]\d|1?\d{1,2})){3}$") {
        return $true
    }
    return $false
}

function ConvertTo-UInt32 {
    param([System.Net.IPAddress]$ip)
    $bytes = $ip.GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function ConvertFrom-UInt32 {
    param([uint32]$num)
    $bytes = [BitConverter]::GetBytes($num)
    [Array]::Reverse($bytes)
    return [System.Net.IPAddress]::new($bytes).ToString()
}

function Get-Class {
    param([System.Net.IPAddress]$ip)
    $addrNum = ConvertTo-UInt32 $ip
    $aStart = ConvertTo-UInt32([System.Net.IPAddress]::new($CLASS_A_START))
    $aEnd   = ConvertTo-UInt32([System.Net.IPAddress]::new($CLASS_A_END))
    $bStart = ConvertTo-UInt32([System.Net.IPAddress]::new($CLASS_B_START))
    $bEnd   = ConvertTo-UInt32([System.Net.IPAddress]::new($CLASS_B_END))
    $cStart = ConvertTo-UInt32([System.Net.IPAddress]::new($CLASS_C_START))
    $cEnd   = ConvertTo-UInt32([System.Net.IPAddress]::new($CLASS_C_END))

    if ($addrNum -ge $aStart -and $addrNum -le $aEnd) { return "A" }
    elseif ($addrNum -ge $bStart -and $addrNum -le $bEnd) { return "B" }
    elseif ($addrNum -ge $cStart -and $addrNum -le $cEnd) { return "C" }
    else { return "不明" }
}

function Get-Segments {
    param(
        [System.Net.IPAddress]$ip,
        [string]$class
    )

    $addrNum = ConvertTo-UInt32 $ip
    $segments = @()
    $segments += ConvertFrom-UInt32 $addrNum  # 自分自身（/32）

    switch ($class) {
        "A" { $endBase = $CLASS_A_BASE }
        "B" { $endBase = $CLASS_B_BASE }
        "C" { $endBase = $CLASS_C_BASE }
        default { return @("クラスが不明なため計算を省略します") }
    }

    # /31 ～ /0 まで順にマスク
    for ($bits = 31; $bits -ge 0; $bits--) {
        $mask = [uint32](([math]::Pow(2,32)-1) -bxor ([math]::Pow(2,(32-$bits))-1))
        $net = $addrNum -band $mask
        $segments += (ConvertFrom-UInt32 $net)
        if ((ConvertFrom-UInt32 $net) -eq $endBase) { break }
    }

    return $segments | Select-Object -Unique
}

# =====================================
# メイン処理
# =====================================
Write-Output "IPアドレス：`"$InputIP`""
Write-Output ""
Write-Output "結果"

if (-not (Test-ValidIPAddress $InputIP)) {
    Write-Output "クラス：不明"
    Write-Output "このIPアドレスを含むセグメント："
    Write-Output "入力形式が正しくないため計算を省略します"
    exit
}

$ipObj = [System.Net.IPAddress]::Parse($InputIP)
$class = Get-Class $ipObj

Write-Output "クラス：$class"
Write-Output "このIPアドレスを含むセグメント："

$segments = Get-Segments -ip $ipObj -class $class
$segmentsQuoted = $segments | ForEach-Object { "`"$_`"" }
Write-Output ($segmentsQuoted -join ", ")
