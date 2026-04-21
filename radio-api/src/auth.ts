export function checkToken(token: string | null | undefined): boolean {
  const expected = process.env.DJ_TOKEN
  if (!expected || !token) return false
  // Constant-time comparison to avoid timing attacks
  if (expected.length !== token.length) return false
  let diff = 0
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ token.charCodeAt(i)
  }
  return diff === 0
}
