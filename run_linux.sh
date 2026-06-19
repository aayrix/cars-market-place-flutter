#!/usr/bin/env bash
# Flutter Linux builds need ld next to clang++. Ubuntu's llvm-21 package
# omits it unless lld-21 is installed. This shim works without sudo.
set -euo pipefail

TOOLCHAIN="$HOME/flutter-linux-toolchain/bin"
mkdir -p "$TOOLCHAIN"

if [[ ! -x "$TOOLCHAIN/clang++" ]]; then
  cat > "$TOOLCHAIN/clang" <<'EOF'
#!/bin/sh
exec /usr/lib/llvm-21/bin/clang "$@"
EOF
  cp "$TOOLCHAIN/clang" "$TOOLCHAIN/clang++"
  chmod +x "$TOOLCHAIN/clang" "$TOOLCHAIN/clang++"
  ln -sf /usr/lib/llvm-21/bin/llvm-ar "$TOOLCHAIN/llvm-ar"
  ln -sf /usr/bin/ld "$TOOLCHAIN/ld"
fi

export PATH="$TOOLCHAIN:$PATH"
exec flutter run -d linux "$@"
