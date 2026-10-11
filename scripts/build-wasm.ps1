param(
    [string] $Emsdk = $env:EMSDK,
    [string] $BeefBuild = 'BeefBuild.exe'
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$output = Join-Path $workspace 'build/wasm'
if (!$Emsdk) { throw 'Pass -Emsdk with the activated Emscripten SDK directory.' }
$emcc = Join-Path $Emsdk 'upstream/emscripten/emcc.exe'
$emar = Join-Path $Emsdk 'upstream/emscripten/emar.exe'
if (!(Test-Path $emcc)) { throw 'Pass -Emsdk with the activated Emscripten SDK directory.' }

# Build a Lua 5.4 library for wasm32; native KeraLua libraries cannot be linked into Wasm.
$luaVersion = '5.4.8'
$luaHash = '4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae'
New-Item -ItemType Directory -Force $output | Out-Null
$archive = Join-Path $output "lua-$luaVersion.tar.gz"
$luaDirectory = Join-Path $output "lua-$luaVersion"
if (!(Test-Path $archive)) {
    Invoke-WebRequest "https://www.lua.org/ftp/lua-$luaVersion.tar.gz" -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $luaHash) {
    throw 'Lua source archive checksum does not match.'
}
if (!(Test-Path $luaDirectory)) {
    & tar -xzf $archive -C $output
    if ($LASTEXITCODE) { throw 'Cannot extract Lua sources.' }
}

$objects = Join-Path $output 'lua-objects'
New-Item -ItemType Directory -Force $objects | Out-Null
$sources = Get-ChildItem (Join-Path $luaDirectory 'src/*.c') |
    Where-Object { $_.Name -notin @('lua.c', 'luac.c') } |
    ForEach-Object { $_.FullName }
Push-Location $objects
try {
    & $emcc -O2 -DLUA_USE_POSIX -c @sources
    if ($LASTEXITCODE) { throw 'Lua Wasm compilation failed.' }
    $objectFiles = Get-ChildItem '*.o' | ForEach-Object { $_.FullName }
    & $emar rcs (Join-Path $output 'liblua54.a') @objectFiles
    if ($LASTEXITCODE) { throw 'Lua Wasm archive creation failed.' }
} finally {
    Pop-Location
}

# Beef uses its configured EmscriptenPath; keep the same activated SDK in Beef's Wasm settings.
& $BeefBuild "-workspace=$workspace" '-project=LuaTinker.Playground' -config=Release -platform=wasm32
if ($LASTEXITCODE) { throw 'Wasm build failed for LuaTinker.Playground.' }
