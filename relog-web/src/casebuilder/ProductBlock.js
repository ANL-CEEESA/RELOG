import Section from "../common/Section";
import Card from "../common/Card";
import Form from "../common/Form";
import TextInputRow from "../common/TextInputRow";
import FileInputRow from "../common/FileInputRow";
import DictInputRow from "../common/DictInputRow";
import { csvParse, extractNumericColumns, generateFile } from "./csv";
import { csvFormat } from "d3";

const ProductBlock = (props) => {
  const onChange = (field, val) => {
    const newProduct = { ...props.value };
    newProduct[field] = val;
    props.onChange(newProduct);
  };

  const onInitialAmountsFile = (contents) => {
    const data = csvParse({
      contents: contents,
      requiredCols: ["latitude (deg)", "longitude (deg)", "name"],
    });
    const result = {};
    data.forEach((el) => {
      result[el["name"]] = {
        "latitude (deg)": el["latitude (deg)"],
        "longitude (deg)": el["longitude (deg)"],
        "amount (tonne)": extractNumericColumns(el, "amount"),
      };
    });
    onChange("initial amounts", result);
  };

  const onInitialAmountsClear = () => {
    onChange("initial amounts", {});
  };

  const onInitialAmountsTemplate = () => {
    generateFile(
      "Initial amounts - Template.csv",
      csvFormat([
        {
          name: "Washakie County",
          "latitude (deg)": "43.8356",
          "longitude (deg)": "-107.6602",
          "amount 1": "21902",
          "amount 2": "6160",
          "amount 3": "2721",
          "amount 4": "12917",
          "amount 5": "18048",
        },
        {
          name: "Platte County",
          "latitude (deg)": "42.1314",
          "longitude (deg)": "-104.9676",
          "amount 1": "16723",
          "amount 2": "8709",
          "amount 3": "22584",
          "amount 4": "12278",
          "amount 5": "7196",
        },
        {
          name: "Park County",
          "latitude (deg)": "44.4063",
          "longitude (deg)": "-109.4153",
          "amount 1": "14731",
          "amount 2": "11729",
          "amount 3": "15562",
          "amount 4": "7703",
          "amount 5": "23349",
        },
      ])
    );
  };

  const onInitialAmountsDownload = () => {
    const results = [];
    for (const [locationName, locationDict] of Object.entries(
      props.value["initial amounts"]
    )) {
      const row = {
        name: locationName,
        "latitude (deg)": locationDict["latitude (deg)"],
        "longitude (deg)": locationDict["longitude (deg)"],
      };
      locationDict["amount (tonne)"].forEach((el, idx) => {
        row[`amount ${idx + 1}`] = el;
      });
      results.push(row);
    }
    generateFile(`Initial amounts - ${props.name}.csv`, csvFormat(results));
  };

  let description = "Not initially available";
  let notInitiallyAvailable = true;
  const nCenters = Object.keys(props.value["initial amounts"]).length;
  if (nCenters > 0) {
    description = `${nCenters} collection centers`;
    notInitiallyAvailable = false;
  }

  return (
    <>
      <Section title={props.name} />
      <Card>
        <Form>
          <h1>General Information</h1>
          <FileInputRow
            value={description}
            label="Initial amounts"
            tooltip="A table indicating the amount of this product initially available at each collection center."
            accept=".csv"
            onFile={onInitialAmountsFile}
            onDownload={onInitialAmountsDownload}
            onClear={onInitialAmountsClear}
            onTemplate={onInitialAmountsTemplate}
            disableDownload={notInitiallyAvailable}
            disableClear={notInitiallyAvailable}
          />

          <h1 style={{ display: nCenters == 0 ? "none" : "block" }}>
            Disposal
          </h1>
          <div style={{ display: nCenters == 0 ? "none" : "block" }}>
            <TextInputRow
              label="Disposal cost"
              unit="$/tonne"
              tooltip="The cost to dispose of one tonne of this product at a collection center, without further processing."
              value={props.value["disposal cost ($/tonne)"]}
              onChange={(v) => onChange("disposal cost ($/tonne)", v)}
              validate="floatList"
            />
            <TextInputRow
              label="Disposal limit"
              unit="tonne"
              tooltip="The maximum amount (in tonnes) of this product that can be disposed of across all collection centers, without further processing."
              value={props.value["disposal limit (tonne)"]}
              onChange={(v) => onChange("disposal limit (tonne)", v)}
              validate="floatList"
              disabled={String(props.value["disposal limit (%)"]).length > 0}
            />

            <TextInputRow
              label="Disposal limit"
              unit="%"
              tooltip="The maximum amount of this product that can be disposed of across all collection centers, without further processing, as a percentage of the total amount available."
              value={props.value["disposal limit (%)"]}
              onChange={(v) => onChange("disposal limit (%)", v)}
              validate="floatList"
              disabled={props.value["disposal limit (tonne)"].length > 0}
            />
          </div>

          <h1>Transportation</h1>
          <TextInputRow
            label="Transportation cost"
            unit="$/km/tonne"
            tooltip="The cost to transport this product."
            value={props.value["transportation cost ($/km/tonne)"]}
            onChange={(v) => onChange("transportation cost ($/km/tonne)", v)}
            validate="floatList"
          />
          <TextInputRow
            label="Transportation energy"
            unit="J/km/tonne"
            tooltip="The energy required to transport this product."
            value={props.value["transportation energy (J/km/tonne)"]}
            onChange={(v) => onChange("transportation energy (J/km/tonne)", v)}
            validate="floatList"
          />
          <DictInputRow
            label="Transportation emissions"
            unit="tonne/km/tonne"
            tooltip="A dictionary mapping the name of each greenhouse gas, produced to transport one tonne of this product along one kilometer, to the amount of gas produced."
            keyPlaceholder="Emission name"
            value={props.value["transportation emissions (tonne/km/tonne)"]}
            onChange={(v) =>
              onChange("transportation emissions (tonne/km/tonne)", v)
            }
            validate="floatList"
          />
        </Form>
      </Card>
    </>
  );
};

export default ProductBlock;
