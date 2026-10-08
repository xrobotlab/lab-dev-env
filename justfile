set dotenv-load := false
set windows-shell := ["powershell.exe", "-NoProfile", "-Command"]

# 共通ツールチェーンとB3環境を導入・同期する。
setup:
    mise install --locked
    uv sync --locked --project b3
    just b3-check

# B3共通Python環境を同期する。
b3-sync:
    uv sync --locked --project b3

# B3用DYNAMIXEL SDK環境が正常に動作することを確認する。
b3-check:
    uv run --locked --project b3 python -c "import importlib.metadata as m; import dynamixel_sdk; print('dynamixel-sdk', m.version('dynamixel-sdk'))"

# 研究室PCの標準環境と、接続されているシリアル機器へのアクセスを確認する。
doctor:
    uv run --locked --project b3 python scripts/doctor.py

# GUIを含めた貸与PCの準備を確認する（CIは通常のdoctorを使用）。
doctor-full:
    uv run --locked --project b3 python scripts/doctor.py --require-gui

# 標準GUIの不足分だけを導入する（既存アプリの更新は行わない）。
gui-setup:
    python scripts/gui_tools.py --install-missing

# 標準CLIとB3環境のDYNAMIXEL SDKのバージョンを表示する。
versions:
    git --version
    mise --version
    python --version
    node --version
    npm --version
    npx --version
    uv --version
    just --version
    pio --version
    gh --version
    uv run --locked --project b3 python -c "import importlib.metadata as m; print('dynamixel-sdk', m.version('dynamixel-sdk'))"
