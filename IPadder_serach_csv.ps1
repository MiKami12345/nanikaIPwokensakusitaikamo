# ================================
# IPadder_serach.ps1
# 各機器のコンフィグファイルから特定のIPアドレスを再帰的に検索し、
# 結果を指定形式のテキストとCSVに出力するスクリプト
#
# 実行方法:
# cdでファイルのあるディレクトリに移動
# .\IPadder_serach.ps1 の実行
# ================================

# ====== 変数定義（依頼者指定）======
$searchIPaddr   = @("10.99.99.99", "10.99.99.", "10.99.")   # 検索対象IPアドレス
$searchfolder   = "C:\Users\XXX\OneDrive\デスクトップ\configlog" # 検索対象フォルダ
$noSearchFolder = @("old", "OLD")                           # 検索対象外フォルダ
$kakuchoshi     = @(".txt", ".log")                         # 検索対象拡張子

# 内部用：拡張子比較を大文字小文字無視で行うため小文字化
$kakuchoshiLower = $kakuchoshi | ForEach-Object { $_.ToLowerInvariant() }

# ====== フォルダ存在確認 ======
if (-not (Test-Path -Path $searchfolder -PathType Container)) {
    Write-Host "エラー: フォルダ $searchfolder が存在しません。処理を中止します。"
    pause
    exit
}

# ====== 出力ファイル名 ======
$ipJoined    = ($searchIPaddr -join "_")
$outputFile  = Join-Path $searchfolder ("serach_result_" + $ipJoined + ".txt")
$csvFile     = Join-Path $searchfolder "serach_target_result.csv"

# ====== 実行前確認 ======
Write-Host "フォルダ `"$searchfolder`" の中から、"
Write-Host ("IPアドレス " + (($searchIPaddr   | ForEach-Object { '\"' + $_ + '\"' }) -join "、") + " を検索します。")
Write-Host ("ただし、フォルダ名が " + (($noSearchFolder | ForEach-Object { '\"' + $_ + '\"' }) -join "、") + " のものは除きます。")
$confirm = Read-Host "実行して良いか？（Yes/No）"

if ($confirm -ne "Yes") {
    Write-Host "処理を中止します"
    pause
    exit
}

# ====== 出力初期化 ======
Set-Content -Path $outputFile -Value "フォルダ`"$searchfolder`"を検索します。"
Add-Content -Path $outputFile -Value ("検索対象IPアドレス：" + (($searchIPaddr   | ForEach-Object { '\"' + $_ + '\"' }) -join "、"))
Add-Content -Path $outputFile -Value ("検索対象外フォルダ名：" + (($noSearchFolder | ForEach-Object { '\"' + $_ + '\"' }) -join "、"))
Add-Content -Path $outputFile -Value ""

# 既存CSV削除（ヘッダなし・データのみ）
if (Test-Path $csvFile) { Remove-Item $csvFile -Force }

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
        $extLower = if ($ext) { $ext.ToLowerInvariant() } else { "" }

        if ($kakuchoshiLower -contains $extLower) {

            # ファイルを1行ずつ読み込んで、行順にマッチを収集（最初の出現順を正しく取得）
            $hits = @()   # 各要素は [pscustomobject] @{ IP=..., Line=... }
            try {
                Get-Content -LiteralPath $file.FullName -ErrorAction Stop | ForEach-Object {
                    $line = $_
                    foreach ($ip in $searchIPaddr) {
                        if ($line -match [regex]::Escape($ip)) {
                            $hits += [pscustomobject]@{ IP = $ip; Line = $line }
                        }
                    }
                }
            }
            catch {
                # 読み取りに失敗した場合はスキップし、テキスト側に通知
                Add-Content -Path $outputFile -Value ($indent + "`tファイル`"$($file.Name)`"→〇読み取り不可（スキップ）")
                continue
            }

            if ($hits.Count -gt 0) {
                # TXT用：ファイル内で出現したIPの重複を除いた順序付きリスト
                $distinctIPsForTxt = @()
                foreach ($h in $hits) {
                    if (-not ($distinctIPsForTxt -contains $h.IP)) { $distinctIPsForTxt += $h.IP }
                }
                $ipStr = ($distinctIPsForTxt | ForEach-Object { '\"' + $_ + '\"' }) -join "、"
                Add-Content -Path $outputFile -Value ($indent + "`tファイル`"$($file.Name)`"→●" + $ipStr + "あり")

                # CSV用：1ファイル = 1行
                $parentFolder = if ($currentFolder -eq $searchfolder) { "-" } else { Split-Path $currentFolder -Leaf }

                # 4列目：最初に出てきたIP（行順の先頭）
                $firstIP   = $hits[0].IP
                # 5列目：上記IPが出てくる最初の行（hits[0]の行）
                $firstLine = $hits[0].Line

                # 6列目：2回目以降に出てきたIP（重複除去＆順序保持）。なければ "-"
                $otherIPsList = @()
                if ($hits.Count -gt 1) {
                    for ($i = 1; $i -lt $hits.Count; $i++) {
                        $ipVal = $hits[$i].IP
                        if (-not ($otherIPsList -contains $ipVal)) {
                            $otherIPsList += $ipVal
                        }
                    }
                }
                $otherIPs = if ($otherIPsList.Count -eq 0) { "-" } else { ($otherIPsList | ForEach-Object { '\"' + $_ + '\"' }) -join "," }

                $csvLine = "$parentFolder,$($file.FullName),$($file.Name),$firstIP,$firstLine,$otherIPs"
                Add-Content -Path $csvFile -Value $csvLine
            }
            else {
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

Write-Host "検索処理が完了しました。結果は以下に保存されています："
Write-Host "  テキスト: $outputFile"
Write-Host "  CSV     : $csvFile"
pause
