{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  libGL,
  libx11,
  libxcursor,
  libxi,
  libxinerama,
  libxrandr,
  libxxf86vm,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "aladdin-2fa-desktop";
  version = "1.3.1.11";

  src = fetchurl {
    url =
      "https://www.aladdin-rd.ru/upload/downloads/aladdin-2fa/"
      + "${finalAttrs.pname}-x64-${finalAttrs.version}.deb";
    hash = "sha256-VYlnvcGAjr+Xc3cFqInaYaUKY2k48FQpWvhDII8UWh0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
  ];

  buildInputs = [
    libGL
    libx11
    libxcursor
    libxi
    libxinerama
    libxrandr
    libxxf86vm
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r usr/* "$out/"
    mv "$out/sbin" "$out/bin"
    substituteInPlace \
      "$out/share/applications/aladdin-2fa-desktop.desktop" \
      --replace-fail "/usr/sbin/aladdin-2fa-desktop" \
      "aladdin-2fa-desktop"

    runHook postInstall
  '';

  meta = {
    description = "Desktop client for Aladdin 2FA authentication";
    homepage = "https://www.aladdin-rd.ru/catalog/aladdin-2fa/";
    license = lib.licenses.unfree;
    mainProgram = "aladdin-2fa-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
