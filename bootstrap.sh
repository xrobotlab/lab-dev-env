#!/usr/bin/env sh
set -eu

MISE_VERSION="2026.10.17"
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MISE_BIN="$HOME/.local/bin/mise"

if [ "$(id -u)" -eq 0 ]; then
    echo "エラー: bootstrap.sh をrootまたはsudoで実行しないでください。" >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "エラー: このリポジトリの取得と実行にはGitが必要です。" >&2
    exit 1
fi

need_mise=1
if [ -x "$MISE_BIN" ] && "$MISE_BIN" --version 2>/dev/null | grep -Fq "$MISE_VERSION"; then
    need_mise=0
fi

if [ "$need_mise" -eq 1 ]; then
    for command in curl tar; do
        if ! command -v "$command" >/dev/null 2>&1; then
            echo "エラー: miseの初期導入には $command が必要です。" >&2
            exit 1
        fi
    done

    os=$(uname -s)
    arch=$(uname -m)
    case "$os:$arch" in
        Linux:x86_64) asset_os="linux"; asset_arch="x64"; sha256="17565e268c5542d8ce944321e17af81e0b741b65af4aa7e8e010ee77376a4aa3" ;;
        Linux:aarch64|Linux:arm64) asset_os="linux"; asset_arch="arm64"; sha256="cac510e51793ad45e65fe92305bdbe4309c9c60b5907badbc7eba111738ab08f" ;;
        Darwin:x86_64) asset_os="macos"; asset_arch="x64"; sha256="e42418100e2f781f9be00b9feaa60378e77551741faececc2bf360992c5410c8" ;;
        Darwin:arm64) asset_os="macos"; asset_arch="arm64"; sha256="d7c50c1683524a764260986ccc9c41c0de5e1fcd491714b5640b657b76781af6" ;;
        *)
            echo "エラー: 未対応のプラットフォームです: $os $arch" >&2
            exit 1
            ;;
    esac

    asset="mise-v${MISE_VERSION}-${asset_os}-${asset_arch}.tar.gz"
    url="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/${asset}"
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
    archive="$tmp_dir/$asset"

    echo "mise ${MISE_VERSION} をユーザー領域にインストールしています..."
    curl --proto '=https' --proto-redir '=https' --fail --show-error --silent --location "$url" --output "$archive"

    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$archive" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$archive" | awk '{print $1}')
    else
        echo "エラー: miseの検証にはsha256sumまたはshasumが必要です。" >&2
        exit 1
    fi

    if [ "$actual" != "$sha256" ]; then
        echo "エラー: miseアーカイブのSHA-256が一致しません: $actual" >&2
        exit 1
    fi

    tar -xzf "$archive" -C "$tmp_dir"
    mkdir -p "$(dirname "$MISE_BIN")"
    cp "$tmp_dir/mise/bin/mise" "$MISE_BIN"
    chmod +x "$MISE_BIN"
    rm -rf "$tmp_dir"
    trap - EXIT HUP INT TERM
fi

cd "$ROOT_DIR"
"$MISE_BIN" trust "$ROOT_DIR/mise.toml"

# PlatformIOで使用するpypiバックエンドが依存するため、Pythonとuvを先に導入する。
"$MISE_BIN" install --locked python uv
"$MISE_BIN" install --locked
"$MISE_BIN" exec -- uv sync --locked --project b3
"$MISE_BIN" exec -- just doctor

configure_shell() {
    shell_name=$(basename "${SHELL:-sh}")
    case "$shell_name" in
        bash)
            rc="$HOME/.bashrc"
            line='eval "$("$HOME/.local/bin/mise" activate bash)"'
            ;;
        zsh)
            rc="${ZDOTDIR:-$HOME}/.zshrc"
            line='eval "$("$HOME/.local/bin/mise" activate zsh)"'
            ;;
        fish)
            rc="$HOME/.config/fish/config.fish"
            line='"$HOME/.local/bin/mise" activate fish | source'
            mkdir -p "$(dirname "$rc")"
            ;;
        *)
            echo "情報: シェル '$shell_name' の設定は変更していません。'mise exec -- just ...' を使用するか、miseの有効化を手動で設定してください。"
            return
            ;;
    esac
    touch "$rc"
    if ! grep -Fqx "$line" "$rc" 2>/dev/null; then
        printf '\n%s\n' "$line" >> "$rc"
        echo "$rc にmiseの有効化設定を追加しました。"
    fi
}

configure_shell

gui_status=0
if [ "${GITHUB_ACTIONS:-}" = true ] && [ "${RUNNER_ENVIRONMENT:-}" = github-hosted ] && [ "${LAB_DEV_ENV_CLEAN_BOOTSTRAP_CI:-}" = 1 ]; then
    echo "GitHub Actionsのクリーンbootstrap試験ではGUI導入を省略します。"
else
    "$MISE_BIN" exec -- python scripts/gui_tools.py --install-missing || gui_status=$?
fi
echo
if [ "$gui_status" -eq 0 ]; then
    echo "セットアップが完了しました。シェルを再起動してから just doctor-full を実行してください。"
elif [ "$gui_status" -eq 2 ]; then
    echo "CLIセットアップ完了。標準GUIの手動確認が必要です。上の公式手順と just doctor-full を確認してください。"
else
    echo "標準GUIの導入に失敗しました。上の表示を確認してください。" >&2
fi
exit "$gui_status"
