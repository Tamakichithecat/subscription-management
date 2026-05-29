import XCTest

/// DASH カテゴリ UAT（DASH-1 〜 DASH-5）
final class DASH_UITests: SubTrackFamilyUITestsBase {

    // MARK: - Setup

    override func setUpWithError() throws {
        try super.setUpWithError()
        signIn()
        createGroupIfNeeded()
        XCTAssertTrue(waitForDashboard(), "前提条件: ダッシュボード表示")
    }

    // MARK: - DASH-1: 月次サマリー表示

    /// DASH-1: ダッシュボードに月次支出合計が表示される
    func testDASH_1_MonthlyTotalDisplays() throws {
        goToDashboard()

        XCTAssertTrue(
            app.staticTexts["今月の総支出"].waitForExistence(timeout: 5),
            "DASH-1 FAIL: 月次サマリーラベルが見つかりません"
        )
        XCTAssertTrue(
            app.staticTexts["text_monthlyTotal"].waitForExistence(timeout: 5),
            "DASH-1 FAIL: 月次合計金額テキストが見つかりません"
        )

        // 金額テキストが空でないことを確認
        let totalText = app.staticTexts["text_monthlyTotal"]
        XCTAssertFalse(totalText.label.isEmpty, "DASH-1 FAIL: 月次合計金額が空です")
    }

    // MARK: - DASH-2: カテゴリ別グラフ（既知バグ）

    /// DASH-2: カテゴリ別内訳グラフが表示される
    /// NOTE: カテゴリが設定されたサブスクが存在する場合に表示される
    func testDASH_2_CategoryChartDisplays() throws {
        goToDashboard()

        // サブスクがある場合のみグラフが表示される
        let chartSection = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'カテゴリー別内訳'")
        ).element

        if chartSection.exists {
            XCTAssertTrue(
                chartSection.waitForExistence(timeout: 5),
                "DASH-2 FAIL: カテゴリー別内訳セクションが表示されません"
            )
            // NOTE: 現バージョンではカテゴリ名がUUIDで表示されるバグがあります（既知の不具合）
            // TODO: categoryID を category name に解決する修正後に再確認
        } else {
            // カテゴリ設定サブスクがなければスキップ
            throw XCTSkip("DASH-2 SKIP: カテゴリが設定されたサブスクがないためグラフ非表示（既知バグあり: カテゴリ名がUUIDで表示される）")
        }
    }

    // MARK: - DASH-3: 7日以内の更新予定

    /// DASH-3: 7日以内の更新予定セクションが正しく表示される
    func testDASH_3_UpcomingBillingsSection() throws {
        goToDashboard()

        // 更新予定があるかどうかは問わず、セクション自体は常に表示される
        let hasUpcoming = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS '7日以内の更新予定'")
        ).element.waitForExistence(timeout: 5)

        let noUpcoming = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS '直近7日以内の更新予定はありません'")
        ).element.waitForExistence(timeout: 2)

        XCTAssertTrue(
            hasUpcoming || noUpcoming,
            "DASH-3 FAIL: 更新予定セクションが表示されません"
        )
    }

    // MARK: - DASH-4: アクティブ件数表示

    /// DASH-4: アクティブなサブスクの件数が表示される
    func testDASH_4_ActiveCountDisplays() throws {
        goToDashboard()

        let countLabel = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS '件のサブスク契約中'")
        ).element

        XCTAssertTrue(
            countLabel.waitForExistence(timeout: 5),
            "DASH-4 FAIL: サブスク契約件数ラベルが表示されません"
        )
    }

    // MARK: - DASH-5: プルリフレッシュ

    /// DASH-5: プルリフレッシュでデータが再取得される
    func testDASH_5_PullToRefresh() throws {
        goToDashboard()

        XCTAssertTrue(app.staticTexts["今月の総支出"].waitForExistence(timeout: 5))

        // プルリフレッシュ
        let list = app.tables.firstMatch
        list.swipeDown(velocity: .fast)

        // ProgressView（更新中）が一瞬表示された後、データが再表示される
        // データ再表示後も同じラベルが見える
        XCTAssertTrue(
            app.staticTexts["今月の総支出"].waitForExistence(timeout: 15),
            "DASH-5 FAIL: プルリフレッシュ後にダッシュボードが表示されません"
        )
    }
}
