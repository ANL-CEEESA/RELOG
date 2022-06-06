import { csvParse, extractNumericColumns, csvFormat } from "./csv";
import { exportValue } from "./export";

test("parse CSV", () => {
  const contents = "name,location,1,2,3\ntest,illinois,100,200,300";
  const actual = csvParse({
    contents: contents,
    requiredCols: ["name", "location"],
  });
  expect(actual.length).toEqual(1);
  expect(actual[0]).toEqual({
    name: "test",
    location: "illinois",
    1: 100,
    2: 200,
    3: 300,
  });
});

test("parse CSV with missing columns", () => {
  const contents = "name,location,1,2,3\ntest,illinois,100,200,300";
  expect(() =>
    csvParse({
      contents: contents,
      requiredCols: ["name", "location", "latitude"],
    })
  ).toThrow('Column "latitude" not found in CSV file.');
});

test("extract numeric columns from object", () => {
  const obj1 = {
    "amount 1": "hello",
    "amount 2": "world",
    "amount 4": "ignored",
  };
  const obj2 = { hello: "world" };
  expect(extractNumericColumns(obj1, "amount")).toEqual(["hello", "world"]);
  expect(extractNumericColumns(obj2, "amount")).toEqual([]);
});

test("generate CSV", () => {
  const data = [
    { name: "alice", age: 20 },
    { name: "bob", age: null },
  ];
  expect(csvFormat(data)).toEqual("name,age\nalice,20\nbob,");
});

test("export value", () => {
  expect(exportValue("1")).toEqual(1);
  expect(exportValue("[1,2,3]")).toEqual([1, 2, 3]);
  expect(exportValue("qwe")).toEqual("qwe");
});
