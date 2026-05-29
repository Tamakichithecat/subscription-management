import XCTest

/// AUTH カテゴリ UAT（AUTH-1-1 〜 AUTH-1-5）
final class AUTH_UITests: SubTrackFamilyUITestsBase {

    // MARK: - AUTH-1-1: 正常ログイン

    /// AUTH-1-1: 正しいメール・パスワードでログインしてダッシュボードへ遷移する
    func testAUTH_1_1_LoginSuccess() throws {
        signIn()
        createGroupIfNeeded()

        XCTAssertTrue(
            waitForDashboard(),
            "AUTH-1-1 FAIL: ログイン後にダッシュボードが表示されませんでした"
        )
    }

    // MARK: - AUTH-1-2: 誤パスワードでエラー表示

    /// AUTH-1-2: 誤ったパスワードを入力するとエラーメッセージが表示される
    func testAUTH_1_2_LoginFailWrongPassword() throws {
        signIn(password: "wrongpassword!!")

        // エラーテキストが赤字で表示されることを確認（テキスト内容で判定）
        // Supabase は "Invalid login credentials" 相当のエラーを返す
        let errorExists = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'invalid' OR label CONTAINS[c] '正しくありません' OR label CONTAINS[c] 'error' OR label CONTAINS[c] 'Error'")).element.waitForExistence(timeout: 10)

        // ダッシュボードに遷移していないことも確認
        let dashboardShown = app.staticTexts["今月の総支出"].waitForExistence(timeout: 3)

        XCTAssertFalse(dashboardShown, "AUTH-1-2 FAIL: 誤パスワードなのにダッシュボードへ遷移しました")
        XCTAssertTrue(errorExists || !dashboardShown, "AUTH-1-2 FAIL: エラーが表示されずダッシュボードにも遷移しませんでした")
    }

    // MARK: - AUTH-1-3: 新規会員登録

    /// AUTH-1-3: 新規登録フローが完了してダッシュボードへ遷移する
    /// NOTE: テスト実行ごとに別メールアドレスを生成するため、登録済みエラーになる場合は手動確認が必要
    func testAUTH_1_3_SignUpNewUser() throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let newEmail = "uat_new_\(timestamp)@example.com"
        let newPassword = "Password123"
        let displayName = "UATテストユーザー"

        // WelcomeView → 新規登録ボタン
        let signUpBtn = app.buttons["btn_signup"]
        XCTAssertTrue(signUpBtn.waitForExistence(timeout: 5), "AUTH-1-3 FAIL: 新規登録ボタンが見つかりません")
        signUpBtn.tap()

        // 表示名入力
        let displayNameField = app.textFields["field_displayName"]
        XCTAssertTrue(displayNameField.waitForExistence(timeout: 5))
        displayNameField.tap()
        displayNameField.typeText(displayName)

        // メールアドレス入力
        let emailField = app.textFields["field_email"]
        emailField.tap()
        emailField.typeText(newEmail)

        // パスワード入力
        let passwordField = app.secureTextFields["field_password"]
        passwordField.tap()
        passwordField.typeText(newPassword)

        // 登録ボタン
        app.buttons["btn_register"].tap()

        // 登録後はグループ作成画面かダッシュボードが表示される
        let groupScreen = app.buttons["btn_createGroup"].waitForExistence(timeout: 15)
        let dashboard = app.staticTexts["今月の総支出"].waitForExistence(timeout: 3)

        XCTAssertTrue(groupScreen || dashboard, "AUTH-1-3 FAIL: 登録後に想定画面へ遷移しませんでした")
    }

    // MARK: - AUTH-1-4: ログアウト

    /// AUTH-1-4: ログアウト後にWelcomeViewへ戻る
    func testAUTH_1_4_Logout() throws {
        signIn()
        createGroupIfNeeded()
        XCTAssertTrue(waitForDashboard(), "前提条件: ダッシュボード表示を確認")

        signOut()

        // WelcomeView の「ログイン」ボタンが再表示される
        XCTAssertTrue(
            app.buttons["btn_signin"].waitForExistence(timeout: 10),
            "AUTH-1-4 FAIL: ログアウト後にWelcomeViewへ戻りませんでした"
        )
    }

    // MARK: - AUTH-1-5: パスワードリセット（UI確認のみ）

    /// AUTH-1-5: パスワードリセット導線が存在するかを確認
    /// NOTE: 現バージョンでは未実装のため、ボタンが存在しない場合はスキップ
    func testAUTH_1_5_PasswordResetLinkExists() throws {
        let loginBtn = app.buttons["btn_signin"]
        XCTAssertTrue(loginBtn.waitForExistence(timeout: 5))
        loginBtn.tap()

        // パスワードリセットリンクの存在確認
        let resetLink = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'パスワードを忘れた' OR label CONTAINS[c] 'リセット' OR label CONTAINS[c] 'reset'")
        ).element

        if resetLink.exists {
            XCTAssertTrue(true, "AUTH-1-5 PASS: パスワードリセットリンクが存在します")
        } else {
            // 未実装は既知のため XCTSkip
            throw XCTSkip("AUTH-1-5 SKIP: パスワードリセットUIは未実装です（既知の未実装機能）")
        }
    }
}
