/** Saf birim testi (emülatörsüz). Denetim H-5. */
const {appCheckMode, appCheckToken, checkAppCheck} = require("../appCheck");

const silent = {warn: jest.fn()};
const ok = async () => ({appId: "app"});
const bad = async () => {
  throw new Error("invalid");
};
const req = (headers = {}) => ({headers});

describe("appCheckMode", () => {
  test("varsayılan monitor", () => {
    expect(appCheckMode({})).toBe("monitor");
    expect(appCheckMode({APP_CHECK_MODE: " "})).toBe("monitor");
  });
  test("bilinen değerler", () => {
    expect(appCheckMode({APP_CHECK_MODE: "ENFORCE"})).toBe("enforce");
    expect(appCheckMode({APP_CHECK_MODE: "off"})).toBe("off");
  });
  test("yazım hatası korumayı kapatmaz, enforce sayılır", () => {
    expect(appCheckMode({APP_CHECK_MODE: "enfroce"})).toBe("enforce");
  });
});

describe("checkAppCheck", () => {
  test("enforce: token yoksa reddeder", async () => {
    const r = await checkAppCheck(req(), {mode: "enforce", verify: ok, log: silent});
    expect(r).toEqual({ok: false, status: "missing"});
  });
  test("enforce: geçersiz token reddedilir", async () => {
    const r = await checkAppCheck(req({"X-Firebase-AppCheck": "x"}), {mode: "enforce", verify: bad, log: silent});
    expect(r).toEqual({ok: false, status: "invalid"});
  });
  test("enforce: geçerli token geçer (başlık adı büyük/küçük harf duyarsız)", async () => {
    const r = await checkAppCheck(req({"x-firebase-appcheck": "t"}), {mode: "enforce", verify: ok, log: silent});
    expect(r).toEqual({ok: true, status: "verified"});
  });
  test("monitor: eksik token geçer ama loglanır", async () => {
    const log = {warn: jest.fn()};
    const r = await checkAppCheck(req(), {mode: "monitor", verify: ok, log, fn: "anthropicProxy"});
    expect(r.ok).toBe(true);
    expect(JSON.parse(log.warn.mock.calls[0][0])).toEqual({event: "app_check", fn: "anthropicProxy", status: "missing", mode: "monitor"});
  });
  test("off: doğrulayıcı hiç çağrılmaz", async () => {
    const verify = jest.fn();
    const r = await checkAppCheck(req({"X-Firebase-AppCheck": "t"}), {mode: "off", verify, log: silent});
    expect(r.ok).toBe(true);
    expect(verify).not.toHaveBeenCalled();
  });
  test("boş başlık token sayılmaz", () => {
    expect(appCheckToken(req({"X-Firebase-AppCheck": ""}))).toBeNull();
  });
});
