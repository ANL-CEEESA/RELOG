import * as d3 from "d3";

export const csvParse = ({ contents, requiredCols }) => {
  const data = d3.csvParse(contents, d3.autoType);
  requiredCols.forEach((col) => {
    if (!(col in data[0])) {
      throw Error(`Column "${col}" not found in CSV file.`);
    }
  });
  return data;
};

export const parseCsv = (contents, requiredCols = []) => {
  const data = d3.csvParse(contents);
  const T = data.columns.length - requiredCols.length;
  let isValid = true;
  for (let t = 0; t < T; t++) {
    requiredCols.push(t + 1);
  }
  requiredCols.forEach((col) => {
    if (!(col in data[0])) {
      console.log(`Column "${col}" not found in CSV file.`);
      isValid = false;
    }
  });
  if (!isValid) return [undefined, undefined];
  return [data, T];
};

export const extractNumericColumns = (obj, prefix) => {
  const result = [];
  for (let i = 1; `${prefix} ${i}` in obj; i++) {
    result.push(obj[`${prefix} ${i}`]);
  }
  return result;
};

export const csvFormat = (data) => {
  return d3.csvFormat(data);
};

export const generateFile = (filename, contents) => {
  var link = document.createElement("a");
  link.setAttribute("href", URL.createObjectURL(new Blob([contents])));
  link.setAttribute("download", filename);
  link.style.visibility = "hidden";
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
};
