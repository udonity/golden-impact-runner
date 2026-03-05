// 条件ベース待機ユーティリティの完全な実装
// 出典: Lace テストインフラストラクチャの改善 (2025-10-03)
// コンテキスト: 任意のタイムアウトを置き換えて15の不安定なテストを修正

import type { ThreadManager } from "~/threads/thread-manager";
import type { LaceEvent, LaceEventType } from "~/threads/types";

/**
 * スレッド内で特定のイベントタイプが出現するのを待つ
 *
 * @param threadManager - クエリ対象のスレッドマネージャー
 * @param threadId - イベントを確認するスレッド
 * @param eventType - 待機するイベントタイプ
 * @param timeoutMs - 最大待機時間（デフォルト5000ms）
 * @returns 最初にマッチしたイベントで解決するPromise
 *
 * 例:
 *   await waitForEvent(threadManager, agentThreadId, 'TOOL_RESULT');
 */
export function waitForEvent(
  threadManager: ThreadManager,
  threadId: string,
  eventType: LaceEventType,
  timeoutMs = 5000,
): Promise<LaceEvent> {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();

    const check = () => {
      const events = threadManager.getEvents(threadId);
      const event = events.find((e) => e.type === eventType);

      if (event) {
        resolve(event);
      } else if (Date.now() - startTime > timeoutMs) {
        reject(new Error(`${eventType}イベントの待機が${timeoutMs}msでタイムアウトしました`));
      } else {
        setTimeout(check, 10); // 効率のため10msごとにポーリング
      }
    };

    check();
  });
}

/**
 * 指定したタイプのイベントが特定の数に達するのを待つ
 *
 * @param threadManager - クエリ対象のスレッドマネージャー
 * @param threadId - イベントを確認するスレッド
 * @param eventType - 待機するイベントタイプ
 * @param count - 待機するイベント数
 * @param timeoutMs - 最大待機時間（デフォルト5000ms）
 * @returns カウントに達したらすべてのマッチするイベントで解決するPromise
 *
 * 例:
 *   // 2つのAGENT_MESSAGEイベントを待つ（初回応答 + 続行）
 *   await waitForEventCount(threadManager, agentThreadId, 'AGENT_MESSAGE', 2);
 */
export function waitForEventCount(
  threadManager: ThreadManager,
  threadId: string,
  eventType: LaceEventType,
  count: number,
  timeoutMs = 5000,
): Promise<LaceEvent[]> {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();

    const check = () => {
      const events = threadManager.getEvents(threadId);
      const matchingEvents = events.filter((e) => e.type === eventType);

      if (matchingEvents.length >= count) {
        resolve(matchingEvents);
      } else if (Date.now() - startTime > timeoutMs) {
        reject(
          new Error(
            `${count}個の${eventType}イベントの待機が${timeoutMs}msでタイムアウトしました（取得数: ${matchingEvents.length}）`,
          ),
        );
      } else {
        setTimeout(check, 10);
      }
    };

    check();
  });
}

/**
 * カスタム述語にマッチするイベントを待つ
 * イベントのタイプだけでなくデータも確認する必要がある場合に便利
 *
 * @param threadManager - クエリ対象のスレッドマネージャー
 * @param threadId - イベントを確認するスレッド
 * @param predicate - イベントがマッチした時にtrueを返す関数
 * @param description - エラーメッセージ用の人間が読める説明
 * @param timeoutMs - 最大待機時間（デフォルト5000ms）
 * @returns 最初にマッチしたイベントで解決するPromise
 *
 * 例:
 *   // 特定のIDを持つTOOL_RESULTを待つ
 *   await waitForEventMatch(
 *     threadManager,
 *     agentThreadId,
 *     (e) => e.type === 'TOOL_RESULT' && e.data.id === 'call_123',
 *     'id=call_123のTOOL_RESULT'
 *   );
 */
export function waitForEventMatch(
  threadManager: ThreadManager,
  threadId: string,
  predicate: (event: LaceEvent) => boolean,
  description: string,
  timeoutMs = 5000,
): Promise<LaceEvent> {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();

    const check = () => {
      const events = threadManager.getEvents(threadId);
      const event = events.find(predicate);

      if (event) {
        resolve(event);
      } else if (Date.now() - startTime > timeoutMs) {
        reject(new Error(`${description}の待機が${timeoutMs}msでタイムアウトしました`));
      } else {
        setTimeout(check, 10);
      }
    };

    check();
  });
}

// 実際のデバッグセッションからの使用例:
//
// 修正前（不安定）:
// ---------------
// const messagePromise = agent.sendMessage('Execute tools');
// await new Promise(r => setTimeout(r, 300)); // 300msでツールが開始されることを期待
// agent.abort();
// await messagePromise;
// await new Promise(r => setTimeout(r, 50));  // 50msで結果が届くことを期待
// expect(toolResults.length).toBe(2);         // ランダムに失敗
//
// 修正後（信頼性あり）:
// ----------------
// const messagePromise = agent.sendMessage('Execute tools');
// await waitForEventCount(threadManager, threadId, 'TOOL_CALL', 2); // ツール開始を待つ
// agent.abort();
// await messagePromise;
// await waitForEventCount(threadManager, threadId, 'TOOL_RESULT', 2); // 結果を待つ
// expect(toolResults.length).toBe(2); // 常に成功
//
// 結果: 合格率60% → 100%、実行時間40%高速化
