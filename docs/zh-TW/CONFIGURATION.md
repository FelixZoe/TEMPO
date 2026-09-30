# Tempo完整設定指南

本頁說明安裝後的用戶端設定。同步服務的 Docker、HTTPS 與備份方式請先閱讀[自託管部署](/zh-TW/DEPLOYMENT)。

## 設定索引

| 功能 | 入口 | 必填內容 |
| --- | --- | --- |
| 多端同步 | 設定 → 自託管同步 | HTTPS 根網址、64 位同步金鑰、獨立裝置名稱 |
| AI 助手 | 設定 → AI 助手 | 服務類型；直連模式另需 API Key |
| 天氣 | 設定 → 天氣與每日一句 | 和風天氣 API Host、Key、Location ID、城市名稱 |
| RSS | RSS → 訂閱管理 | RSS/Atom 網址與來源分類 |

## 多端同步

所有裝置填入相同的伺服器根網址與同步金鑰，但使用不同的裝置名稱。網址不要追加 `/v1/sync`。儲存時會先驗證連線，再寫入安全儲存並立即同步。

Tempo僅供單一使用者。前景裝置會即時接收變更；離線修改會在網路恢復後補傳。iOS 被系統暫停時無法保持一般長連線，回到前景後會立即追上。

## AI 助手

建議將服務商金鑰只放在伺服器 `.env`：

```dotenv
AI_BASE_URL=https://api.openai.com/v1/chat/completions
AI_API_KEY=你的伺服器金鑰
AI_MODEL=gpt-5.6-terra
```

重新執行 `docker compose up -d`，用戶端選擇自託管模式。OpenAI 直連預設為 `gpt-5.6-terra`，DeepSeek 直連預設為 `deepseek-flash`；已儲存的自訂模型不會被升級覆蓋。直連 Key 只保存在系統安全儲存中。

## 天氣與每日一句

API Host 只填和風天氣為專案分配的網域，不含 `https://` 與路徑；再填入同一專案的 Key、Location ID 和顯示城市。儲存前先測試連線。每日一句由 Hitokoto 提供，不需要金鑰。兩者顯示於收件匣頂部，離線時保留最近快取。

## 安全與更新

同步金鑰、AI 直連 Key 與天氣 Key 都不會寫入同步資料。iOS / Android 覆蓋安裝需要穩定的套件識別碼與簽名。可由「設定 → 軟體更新」前往最新 GitHub Release。

反向代理、備份與容器排錯請繼續閱讀[自託管部署](/zh-TW/DEPLOYMENT)。
