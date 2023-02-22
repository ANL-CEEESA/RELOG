import { evaluateExpr } from "./expr";

test("parse expression", () => {
  // Basic expressions
  expect(evaluateExpr("1 + 1")).toEqual(2);
  expect(evaluateExpr("2 * 5")).toEqual(10);
  expect(evaluateExpr("2 * (3 + 5)")).toEqual(16);
  expect(evaluateExpr("14 / 2")).toEqual(7);
  expect(evaluateExpr("10 - 3")).toEqual(7);
  expect(evaluateExpr("-10")).toEqual(-10);
  expect(evaluateExpr("+10")).toEqual(10);
  expect(evaluateExpr("2^3")).toEqual(8);
  expect(evaluateExpr("2^(3 + 1)")).toEqual(16);

  // With data
  expect(evaluateExpr("x + 1", { x: 10 })).toEqual(11);
  expect(evaluateExpr("2 ^ (3 + x)", { x: 1 })).toEqual(16);
  expect(evaluateExpr("x + y", { x: 1, y: 2 })).toEqual(3);
});
