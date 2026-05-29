import XCTest

/// GRP カテゴリ UAT（GRP-1-1 〜 GRP-4-1）
final class GRP_UITests: SubTrackFamilyUITestsBase {

    // MARK: - GRP-1-1: グループ作成

    /// GRP-1-1: グループを新規作成してダッシュボードへ遷移する
    func testGRP_1_1_CreateGroup() throws {
        signIn()

        // すでにグループがある場合は設定 → Family タブから新規グループ作成
        if waitForDashboard(timeout: 8) {
            goToFamily()
            // 「…」メニューから「新しいグループを作成」
            let moreMenu = app.buttons["ellipsis.circle"]
            XCTAssertTrue(moreMenu.waitForExistence(timeout: 5))
            moreMenu.tap()
            app.buttons["新しいグループを作成"].tap()
        } else {
            // グループ未所属 → GroupSelectionView
            let createBtn = app.buttons["btn_createGroup"]
            XCTAssertTrue(createBtn.waitForExistence(timeout: 8), "GRP-1-1 FAIL: グループ作成ボタンが見つかりません")
            createBtn.tap()
        }

        let groupNameField = app.textFields["field_groupName"]
        XCTAssertTrue(groupNameField.waitForExistence(timeout: 5), "GRP-1-1 FAIL: グループ名フィールドが見つかりません")
        groupNameField.tap()
        groupNameField.typeText("UATグループ")

        app.buttons["btn_createGroupConfirm"].tap()

        XCTAssertTrue(
            waitForDashboard(timeout: 15),
            "GRP-1-1 FAIL: グループ作成後にダッシュボードへ遷移しませんでした"
        )
    }

    // MARK: - GRP-2-1: 招待コード表示

    /// GRP-2-1: オーナーが招待コードを確認できる
    func testGRP_2_1_InviteCodeVisible() throws {
        signIn()
        createGroupIfNeeded()
        XCTAssertTrue(waitForDashboard(), "前提条件: ダッシュボード表示")

        goToFamily()

        // 「招待コードを確認」ボタン（オーナーのみ表示）
        let inviteBtn = app.buttons.containing(
            NSPredicate(format: "label CONTAINS '招待コード'")
        ).element
        XCTAssertTrue(inviteBtn.waitForExistence(timeout: 5), "GRP-2-1 FAIL: 招待コード確認ボタンが見つかりません（オーナー権限が必要）")
        inviteBtn.tap()

        // 招待コードテキストが表示される
        let inviteCodeText = app.staticTexts["text_inviteCode"]
        XCTAssertTrue(inviteCodeText.waitForExistence(timeout: 5), "GRP-2-1 FAIL: 招待コードが表示されませんでした")
        XCTAssertFalse(inviteCodeText.label.isEmpty, "GRP-2-1 FAIL: 招待コードが空です")
    }

    // MARK: - GRP-2-2: 招待コード再生成

    /// GRP-2-2: 招待コードを再生成すると新しいコードになる
    func testGRP_2_2_RegenerateInviteCode() throws {
        signIn()
        createGroupIfNeeded()
        XCTAssertTrue(waitForDashboard(), "前提条件: ダッシュボード表示")

        goToFamily()

        let inviteBtn = app.buttons.containing(
            NSPredicate(format: "label CONTAINS '招待コード'")
        ).element
        XCTAssertTrue(inviteBtn.waitForExistence(timeout: 5), "前提条件: 招待コードボタン")
        inviteBtn.tap()

        let inviteCodeText = app.staticTexts["text_inviteCode"]
        XCTAssertTrue(inviteCodeText.waitForExistence(timeout: 5))
        let originalCode = inviteCodeText.label

        // 再生成ボタン
        let regenerateBtn = app.buttons.containing(
            NSPredicate(format: "label CONTAINS '再生成'")
        ).element
        XCTAssertTrue(regenerateBtn.waitForExistence(timeout: 5), "GRP-2-2 FAIL: 再生成ボタンが見つかりません")
        regenerateBtn.tap()

        // コードが変わるまで待機
        let newCodePredicate = NSPredicate(format: "label != %@", originalCode)
        let codeChanged = XCTNSPredicateExpectation(predicate: newCodePredicate, object: inviteCodeText)
        let result = XCTWaiter().wait(for: [codeChanged], timeout: 10)

        XCTAssertEqual(result, .completed, "GRP-2-2 FAIL: 招待コードが再生成後も変わりませんでした（旧: \(originalCode)）")
    }

    // MARK: - GRP-3-1: 招待コードで参加

    /// GRP-3-1: 招待コードを入力してグループに参加できる
    /// NOTE: 実際の招待コードが必要なため、別途取得してから実行してください
    func testGRP_3_1_JoinGroupWithInviteCode() throws {
        throw XCTSkip("GRP-3-1 SKIP: 招待コードを別アカウントから取得する手動準備が必要です")
    }

    // MARK: - GRP-4-1: メンバー削除

    /// GRP-4-1: オーナーがメンバーを削除できる
    /// NOTE: 2アカウント以上のメンバー参加が必要
    func testGRP_4_1_RemoveMember() throws {
        throw XCTSkip("GRP-4-1 SKIP: 複数メンバーの参加が必要なため手動実施が必要です")
    }
}
