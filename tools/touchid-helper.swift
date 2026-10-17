// dsh-startup-screen — Touch ID 验证助手
//
// 由插件 Host 半侧 spawn 调用，弹真正的 macOS 系统验证框：
//   - 有 Touch ID 的机器 → 指纹验证
//   - 没有 / 指纹不可用   → 自动换成输入登录密码（同一次系统验证）
// 用途是给启动动画的「身份资料确认」这一步提供真实验证，**不是安全边界**。
//
// 用法：dsh-startup-auth [提示语]
// 退出码：0 = 通过   1 = 取消 / 失败 / 超时   2 = 设备不支持   3 = 参数或内部错误
// 说明信息（失败原因）写到 stderr。

import Foundation
import LocalAuthentication

let args = CommandLine.arguments
let reason = args.count > 1 && !args[1].isEmpty
  ? args[1]
  : "确认身份，继续启动 DeepSeek Harness"

// 超时上限：用户放着不管时不要让插件永远挂着
let timeoutSeconds: Double = 60

func fail(_ code: Int32, _ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(code)
}

let ctx = LAContext()
ctx.localizedCancelTitle = "跳过验证"
ctx.interactionNotAllowed = false

// deviceOwnerAuthentication = 生物识别，拿不到就退回设备口令（macOS 登录密码）
let policy: LAPolicy = .deviceOwnerAuthentication

var canError: NSError?
guard ctx.canEvaluatePolicy(policy, error: &canError) else {
  fail(2, canError?.localizedDescription ?? "这台设备不支持系统验证")
}

let semaphore = DispatchSemaphore(value: 0)
var passed = false
var failureMessage = ""

ctx.evaluatePolicy(policy, localizedReason: reason) { success, error in
  passed = success
  if let error = error { failureMessage = error.localizedDescription }
  semaphore.signal()
}

if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
  ctx.invalidate()
  fail(1, "等待验证超时")
}

if passed { exit(0) }
fail(1, failureMessage.isEmpty ? "验证未通过" : failureMessage)
