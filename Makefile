.PHONY: setup generate open clean

# XcodeGenをインストールしてプロジェクトを生成する
setup:
	brew install xcodegen
	$(MAKE) generate

# project.yml からXcodeプロジェクトを生成する
generate:
	xcodegen generate

# Xcodeプロジェクトを開く
open: generate
	open SubTrackFamily.xcodeproj

# 生成ファイルを削除する（再生成時に使用）
clean:
	rm -rf SubTrackFamily.xcodeproj
