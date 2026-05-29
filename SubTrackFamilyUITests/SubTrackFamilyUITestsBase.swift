import XCTest

// MARK: - Base class

class SubTrackFamilyUITestsBase: XCTestCase {

    var app: XCUIApplication!

    // テスト用アカウント（Xcodeスキームの環境変数から取得）
    var testEmail: String {
        ProcessInfo.processInfo.environment["UAT_TEST_EMAIL"] ?? "uat@example.com"
    }
    var testPassword: String {
        ProcessInfo.processInfo.environment["UAT_TEST_PASSWORD"] ?? "password123"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["SUPABASE_URL"] =
            ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
        app.launchEnvironment["SUPABASE_ANON_KEY"] =
            ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        app.launchEnvironment["UAT_TEST_EMAIL"] = testEmail
        app.launchEnvironment["UAT_TEST_PASSWORD"] = testPassword
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// WelcomeView から SignIn 画面へ進んでログインする
    func signIn(email: String? = nil, password: String? = nil) {
        let e = email ?? testEmail
        let p = password ?? testPassword

        // WelcomeView が表示されている場合のみログインボタンをタップ
        let loginBtn = app.buttons["btn_signin"]
        if loginBtn.waitForExistence(timeout: 5) {
            loginBtn.tap()
        }

        let emailField = app.textFields["field_email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "メールアドレスフィールドが見つかりません")
        emailField.tap()
        emailField.typeText(e)

        let passwordField = app.secureTextFields["field_password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "パスワードフィールドが見つかりません")
        passwordField.tap()
        passwordField.typeText(p)

        app.buttons["btn_login"].tap()
    }

    /// サインイン後にグループ選択画面が出た場合、新規グループを作成する
    func createGroupIfNeeded(name: String = "テストグループ") {
        let createBtn = app.buttons["btn_createGroup"]
        if createBtn.waitForExistence(timeout: 5) {
            createBtn.tap()
            let nameField = app.textFields["field_groupName"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap()
            nameField.typeText(name)
            app.buttons["btn_createGroupConfirm"].tap()
        }
    }

    /// ダッシュボード（ホーム）が表示されるまで待機する
    @discardableResult
    func waitForDashboard(timeout: TimeInterval = 15) -> Bool {
        app.staticTexts["今月の総支出"].waitForExistence(timeout: timeout)
    }

    /// タブバーの「サブスク一覧」タブへ遷移する
    func goToSubscriptionList() {
        app.tabBars.buttons["サブスク一覧"].tap()
    }

    /// タブバーの「ダッシュボード」タブへ遷移する
    func goToDashboard() {
        app.tabBars.buttons["ホーム"].tap()
    }

    /// タブバーの「ファミリー」タブへ遷移する
    func goToFamily() {
        app.tabBars.buttons["ファミリー"].tap()
    }

    /// タブバーの「契約一覧」タブへ遷移する
    func goToContractList() {
        app.tabBars.buttons["契約情報"].tap()
    }

    /// タブバーの「設定」タブへ遷移する
    func goToSettings() {
        app.tabBars.buttons["設定"].tap()
    }

    /// タブバーの「レポート」タブへ遷移する
    func goToReports() {
        app.tabBars.buttons["レポート"].tap()
    }

    /// サブスク追加フォームを開いてサービスを登録する
    func addSubscription(
        name: String,
        amount: String = "980",
        currency: String = "JPY"
    ) {
        goToSubscriptionList()
        app.buttons["btn_addSubscription"].tap()

        let nameField = app.textFields["field_serviceName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)

        let amountField = app.textFields["field_amount"]
        amountField.tap()
        amountField.typeText(amount)

        app.buttons["btn_saveSubscription"].tap()
    }

    /// ログアウトを実行する
    func signOut() {
        goToSettings()
        let signOutBtn = app.buttons["btn_signout"]
        XCTAssertTrue(signOutBtn.waitForExistence(timeout: 5))
        signOutBtn.tap()
        // 確認ダイアログの「ログアウト」ボタン
        let confirmBtn = app.buttons["ログアウト"]
        if confirmBtn.waitForExistence(timeout: 3) {
            confirmBtn.tap()
        }
    }
}
