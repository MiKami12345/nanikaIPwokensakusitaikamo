# ================================
# IPadder_serach.ps1
# 各機器のコンフィグファイルから特定のIPアドレスを再帰的に検索し、
# 結果を指定形式のテキストに出力するスクリプト
# 
# 実行方法
# 
# cdでファイルのあるディレクトリに移動
# .\IPadder_serach.ps1の実行
# ================================

# ====== 変数定義（依頼者指定）======
$searchIPaddr   = @("10.99.99.99", "10.99.99.", "10.99.")   # 検索対象IPアドレス
$searchfolder   = "C:\Users\111"                               # 検索対象フォルダ
$noSearchFolder = @("old", "OLD")                              # 検索対象外フォルダ
$kakuchoshi     = @(".txt", ".log")                            # 検索対象拡張子

# ====== フォルダ存在確認 ======
if (-not (Test-Path -Path $searchfolder -PathType Container)) {
    Write-Host "エラー: フォルダ $searchfolder が存在しません。処理を中止します。"
    pause
    exit
}

# ====== 出力ファイル名 ======
$ipJoined    = ($searchIPaddr -join "_")
$outputFile  = Join-Path $searchfolder ("serach_result_" + $ipJoined + ".txt")

# ====== 実行前確認 ======
Write-Host "フォルダ `"$searchfolder`" の中から、"
Write-Host ("IPアドレス " + (( $searchIPaddr | ForEach-Object { "`"$_`"" } ) -join "、") + " を検索します。")
Write-Host ("ただし、フォルダ名が " + (( $noSearchFolder | ForEach-Object { "`"$_`"" } ) -join "、") + " のものは除きます。")
$confirm = Read-Host "実行して良いか？（Yes/No）"

if ($confirm -ne "Yes") {
    Write-Host "処理を中止します"
    pause
    exit
}

# ====== 出力初期化 ======
Set-Content -Path $outputFile -Value "フォルダ`"$searchfolder`"を検索します。"
Add-Content -Path $outputFile -Value ("検索対象IPアドレス：" + (( $searchIPaddr | ForEach-Object { "`"$_`"" } ) -join "、"))
Add-Content -Path $outputFile -Value ("検索対象外フォルダ名：" + (( $noSearchFolder | ForEach-Object { "`"$_`"" } ) -join "、"))
Add-Content -Path $outputFile -Value ""

# ====== 再帰的検索関数 ======
function Search-Folder {
    param (
        [string]$currentFolder,
        [int]$indentLevel
    )

    $indent = "`t" * $indentLevel
    Add-Content -Path $outputFile -Value ""
    Add-Content -Path $outputFile -Value ($indent + "フォルダ`"$currentFolder`"")

    # ---- ファイルの処理 ----
    $files = Get-ChildItem -Path $currentFolder -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $ext = [System.IO.Path]::GetExtension($file.Name)
        if ($kakuchoshi -contains $ext) {
            $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
            $foundIPs = @()
            foreach ($ip in $searchIPaddr) {
                if ($content -match [regex]::Escape($ip)) {
                    $foundIPs += "`"$ip`""
                }
            }
            if ($foundIPs.Count -gt 0) {
                Add-Content -Path $outputFile -Value ($indent + "`tファイル`"$($file.Name)`"→●" + ($foundIPs -join "、") + "あり")
            } else {
                Add-Content -Path $outputFile -Value ($indent + "`tファイル`"$($file.Name)`"→〇検索対象IPアドレスなし")
            }
        }
    }

    # ---- フォルダの処理 ----
    $folders = Get-ChildItem -Path $currentFolder -Directory -ErrorAction SilentlyContinue
    foreach ($folder in $folders) {
        if ($noSearchFolder -contains $folder.Name) {
            Add-Content -Path $outputFile -Value ($indent + "`tフォルダ`"$($folder.Name)`"→◎検索対象外")
        } else {
            Search-Folder -currentFolder $folder.FullName -indentLevel ($indentLevel + 1)
        }
    }
}

# ====== メイン処理 ======
Search-Folder -currentFolder $searchfolder -indentLevel 0

Write-Host "検索処理が完了しました。結果は $outputFile に保存されています。"
pause