const {checkSession, isAllowedSession} = require("../authClaims");

const token = (provider, over = {}) => ({firebase: {sign_in_provider: provider}, ...over});

describe("checkSession (H-5, ADR-0010)", () => {
  test("doğrulanmış e-posta/şifre, Google ve Apple geçer", () => {
    expect(isAllowedSession(token("password", {email_verified: true}))).toBe(true);
    expect(isAllowedSession(token("google.com"))).toBe(true);
    expect(isAllowedSession(token("apple.com"))).toBe(true);
  });

  test.each([
    ["doğrulanmamış e-posta", token("password", {email_verified: false}), "email-not-verified"],
    ["email_verified alanı yok", token("password"), "email-not-verified"],
    ["anonim", token("anonymous"), "provider-anonymous"],
    ["eski köprü custom token'ı", token("custom", {provider: "supabase"}), "provider-custom"],
    ["telefon", token("phone"), "provider-phone"],
  ])("%s reddedilir", (_, decoded, reason) => {
    expect(checkSession(decoded)).toEqual({ok: false, reason});
  });

  test("bozuk girdi reddedilir", () => {
    expect(isAllowedSession(null)).toBe(false);
    expect(isAllowedSession({})).toBe(false);
  });
});
