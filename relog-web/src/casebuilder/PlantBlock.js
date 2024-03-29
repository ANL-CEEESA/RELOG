import Section from "../common/Section";
import Card from "../common/Card";
import Form from "../common/Form";
import TextInputRow from "../common/TextInputRow";
import FileInputRow from "../common/FileInputRow";
import DictInputRow from "../common/DictInputRow";
import { csvFormat, csvParse, generateFile } from "./csv";

const PlantBlock = (props) => {
  const onChange = (val, field1, field2, field3) => {
    const newPlant = { ...props.value };
    if (field3 !== undefined) {
      newPlant[field1][field2][field3] = val;
    } else if (field2 !== undefined) {
      newPlant[field1][field2] = val;
    } else {
      newPlant[field1] = val;
    }
    props.onChange(newPlant);
  };

  const onCandidateLocationsTemplate = () => {
    generateFile(
      "Candidate locations - Template.csv",
      csvFormat([
        {
          name: "Washakie County",
          "latitude (deg)": "43.8356",
          "longitude (deg)": "-107.6602",
          "initial capacity (tonne)": "0",
          "area cost factor": "0.88",
        },
        {
          name: "Platte County",
          "latitude (deg)": "42.1314",
          "longitude (deg)": "-104.9676",
          "initial capacity (tonne)": "0",
          "area cost factor": "1.29",
        },
        {
          name: "Park County",
          "latitude (deg)": "44.4063",
          "longitude (deg)": "-109.4153",
          "initial capacity (tonne)": "0",
          "area cost factor": "0.99",
        },
        {
          name: "Goshen County",
          "latitude (deg)": "42.0853",
          "longitude (deg)": "-104.3534",
          "initial capacity (tonne)": "0",
          "area cost factor": "1",
        },
      ])
    );
  };

  const onCandidateLocationsFile = (contents) => {
    const data = csvParse({
      contents: contents,
      requiredCols: [
        "name",
        "latitude (deg)",
        "longitude (deg)",
        "area cost factor",
        "initial capacity (tonne)",
      ],
    });
    const result = {};
    data.forEach((el) => {
      let { name, ...props } = el;
      result[name] = props;
    });
    onChange(result, "locations");
  };

  const onCandidateLocationsDownload = () => {
    const result = [];
    for (const [locationName, locationDict] of Object.entries(
      props.value["locations"]
    )) {
      result.push({
        name: locationName,
        ...locationDict,
      });
    }
    generateFile(`Candidate locations - ${props.name}.csv`, csvFormat(result));
  };

  const onCandidateLocationsClear = () => {
    onChange({}, "locations");
  };

  let description = "No locations set";
  const nCenters = Object.keys(props.value["locations"]).length;
  if (nCenters > 0) description = `${nCenters} locations`;

  const shouldDisableMaxCap =
    props.value["minimum capacity (tonne)"] ===
    props.value["maximum capacity (tonne)"];

  return (
    <>
      <Section title={props.name} />
      <Card>
        <Form>
          <h1>General information</h1>
          <FileInputRow
            label="Candidate locations"
            tooltip="A table describing potential locations where plants can be built and their characteristics."
            onTemplate={onCandidateLocationsTemplate}
            onFile={onCandidateLocationsFile}
            onDownload={onCandidateLocationsDownload}
            onClear={onCandidateLocationsClear}
            value={description}
          />

          <h1>Inputs & Outputs</h1>
          <TextInputRow
            label="Input"
            tooltip="The name of the product that this plant takes as input."
            disabled="disabled"
            value={props.value["input"]}
          />
          <DictInputRow
            label="Outputs"
            unit="tonne/tonne"
            tooltip="A dictionary specifying how many tonnes of each product is produced for each tonne of input."
            value={props.value["outputs (tonne/tonne)"]}
            onChange={(v) => onChange(v, "outputs (tonne/tonne)")}
            disableKeys={true}
          />

          <h1>Capacity & Costs</h1>
          <TextInputRow
            label="Minimum capacity"
            unit="tonne"
            tooltip="The minimum size of the plant."
            value={props.value["minimum capacity (tonne)"]}
            onChange={(v) => onChange(v, "minimum capacity (tonne)")}
          />
          <TextInputRow
            label="Opening cost (min capacity)"
            unit="$"
            tooltip="The cost to open the plant at minimum capacity."
            value={props.value["opening cost (min capacity) ($)"]}
            onChange={(v) => onChange(v, "opening cost (min capacity) ($)")}
          />
          <TextInputRow
            label="Fixed operating cost (min capacity)"
            unit="$"
            tooltip="The cost to keep the plant open, even if the plant doesn't process anything."
            value={props.value["fixed operating cost (min capacity) ($)"]}
            onChange={(v) =>
              onChange(v, "fixed operating cost (min capacity) ($)")
            }
          />
          <TextInputRow
            label="Maximum capacity"
            unit="tonne"
            tooltip="The maximum size of the plant."
            value={props.value["maximum capacity (tonne)"]}
            onChange={(v) => onChange(v, "maximum capacity (tonne)")}
          />
          <TextInputRow
            label="Opening cost (max capacity)"
            unit="$"
            tooltip="The cost to open a plant of this size."
            value={
              shouldDisableMaxCap
                ? ""
                : props.value["opening cost (max capacity) ($)"]
            }
            onChange={(v) => onChange(v, "opening cost (max capacity) ($)")}
            disabled={shouldDisableMaxCap}
          />
          <TextInputRow
            label="Fixed operating cost (max capacity)"
            unit="$"
            tooltip="The cost to keep the plant open, even if the plant doesn't process anything."
            value={
              shouldDisableMaxCap
                ? ""
                : props.value["fixed operating cost (max capacity) ($)"]
            }
            onChange={(v) =>
              onChange(v, "fixed operating cost (max capacity) ($)")
            }
            disabled={shouldDisableMaxCap}
          />
          <TextInputRow
            label="Variable operating cost"
            unit="$/tonne"
            tooltip="The cost that the plant incurs to process each tonne of input."
            value={props.value["variable operating cost ($/tonne)"]}
            onChange={(v) => onChange(v, "variable operating cost ($/tonne)")}
          />
          <TextInputRow
            label="Energy expenditure"
            unit="GJ/tonne"
            tooltip="The energy required to process one tonne of the input."
            value={props.value["energy (GJ/tonne)"]}
            onChange={(v) => onChange(v, "energy (GJ/tonne)")}
          />

          <h1>Storage</h1>
          <TextInputRow
            label="Storage cost"
            unit="$/tonne"
            tooltip="The cost to store a tonne of input product for one time period."
            value={props.value["storage"]["cost ($/tonne)"]}
            onChange={(v) => onChange(v, "storage", "cost ($/tonne)")}
          />
          <TextInputRow
            label="Storage limit"
            unit="tonne"
            tooltip="The maximum amount of input product this plant can have in storage at any given time."
            value={props.value["storage"]["limit (tonne)"]}
            onChange={(v) => onChange(v, "storage", "limit (tonne)")}
          />

          <h1>Disposal</h1>
          <DictInputRow
            label="Disposal cost"
            unit="$/tonne"
            tooltip="The cost to dispose of the product."
            value={props.value["disposal cost ($/tonne)"]}
            onChange={(v) => onChange(v, "disposal cost ($/tonne)")}
            disableKeys={true}
          />
          <DictInputRow
            label="Disposal limit"
            unit="tonne"
            tooltip="The maximum amount that can be disposed of. If an unlimited amount can be disposed, leave blank."
            value={props.value["disposal limit (tonne)"]}
            onChange={(v) => onChange(v, "disposal limit (tonne)")}
            disableKeys={true}
            valuePlaceholder="Unlimited"
          />

          <h1>Emissions</h1>
          <DictInputRow
            label="Emissions"
            unit="tonne/tonne"
            tooltip="A dictionary mapping the name of each greenhouse gas, produced to process each tonne of input, to the amount of gas produced (in tonne)."
            value={props.value["emissions (tonne/tonne)"]}
            onChange={(v) => onChange(v, "emissions (tonne/tonne)")}
            keyPlaceholder="Emission name"
            valuePlaceholder="0"
          />
        </Form>
      </Card>
    </>
  );
};

export default PlantBlock;
