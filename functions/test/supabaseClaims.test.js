/** Saf birim testi (emülatörsüz). Denetim H-5 / L-6. */
const {validateSupabaseClaims, isBridgedSession} = require("../supabaseClaims");

const good = {
  sub: "7b0c2f7e-2a0e-4c38-9b8f-3c1f0d7a9e11",
  aud: "authenticated",
  role: "authenticated",
  is_anonymous: false,
};

describe("validateSupabaseClaims", () => {
  test("normal oturum geçer", () => {
    expect(validateSupabaseClaims(good)).toEqual({ok: true, uid: good.sub});
    expect(validateSupabaseClaims({...good, aud: ["authenticated"]}).ok).toBe(true);
  });

  test.each([
    ["anonim oturum", {is_anonymous: true}, "anonymous"],
    ["anon rolü", {role: "anon"}, "bad-role"],
    ["service_role", {role: "service_role"}, "bad-role"],
    ["yanlış audience", {aud: "other"}, "bad-audience"],
    ["subject yok", {sub: undefined}, "bad-subject"],
    ["string olmayan subject", {sub: 42}, "bad-subject"],
    ["128'den uzun subject", {sub: "x".repeat(129)}, "bad-subject"],
  ])("%s reddedilir", (_, over, reason) => {
    expect(validateSupabaseClaims({...good, ...over})).toEqual({ok: false, reason});
  });

  test("yük yoksa reddedilir", () => {
    expect(validateSupabaseClaims(null).ok).toBe(false);
  });
});

describe("isBridgedSession", () => {
  test("köprü oturumu geçer", () => {
    expect(isBridgedSession({firebase: {sign_in_provider: "custom"}, provider: "supabase"})).toBe(true);
  });
  test.each([
    ["anonim", {firebase: {sign_in_provider: "anonymous"}}],
    ["e-posta/şifre", {firebase: {sign_in_provider: "password"}, provider: "supabase"}],
    ["claim'siz custom token", {firebase: {sign_in_provider: "custom"}}],
    ["başka claim'li custom token", {firebase: {sign_in_provider: "custom"}, provider: "other"}],
  ])("%s reddedilir", (_, decoded) => {
    expect(isBridgedSession(decoded)).toBe(false);
  });
});
