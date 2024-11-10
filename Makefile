PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

.PHONY: build install uninstall clean test

# ビルド
build:
	swift build -c release --disable-sandbox

# テスト実行
test:
	swift test

# デバッグビルド
debug:
	swift build

# インストール
install: build
	install -d "$(BINDIR)"
	install ".build/release/RemarkCLI" "$(BINDIR)/remark"

# アンインストール
uninstall:
	rm -f "$(BINDIR)/remark"

# クリーンアップ
clean:
	rm -rf .build

# すべての依存関係を更新
update:
	swift package update

# 依存関係の解決
resolve:
	swift package resolve
