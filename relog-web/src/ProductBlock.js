import { useState } from 'react';
import Section from './Section';
import Card from './Card';
import Form from './Form';
import TextInputRow from './TextInputRow';
import FileInputRow from './FileInputRow';
import DictInputRow from './DictInputRow';
import * as d3 from 'd3';

const ProductBlock = (props) => {
    const onChange = (field, val) => {
        const newProduct = { ...props.value };
        newProduct[field] = val;
        props.onChange(newProduct);
    };

    const onInitialAmountsFile = (contents) => {
        const data = d3.csvParse(contents);
        const T = data.columns.length - 3;

        // Construct list of required columns
        let isValid = true;
        const requiredCols = ["latitude (deg)", "longitude (deg)", "name"];
        for (let t = 0; t < T; t++) {
            requiredCols.push(t + 1);
        }

        // Check required columns
        requiredCols.forEach(col => {
            if (!(col in data[0])) {
                console.log(`Column "${col}" not found in CSV file.`);
                isValid = false;
            }
        });
        if (!isValid) return;

        // Construct initial amounts dict
        const result = {};
        data.forEach(el => {
            let amounts = [];
            for (let t = 0; t < T; t++) {
                amounts.push(el[t + 1]);
            }
            result[el["name"]] = {
                "latitude (deg)": el["latitude (deg)"],
                "longitude (deg)": el["longitude (deg)"],
                "amount (tonne)": amounts,
            };
        });

        onChange("initial amounts", result);
    };

    const onInitialAmountsClear = () => {
        onChange("initial amounts", {});
    };

    const onInitialAmountsTemplate = () => {
        exportToCsv(
            "Initial amounts - Template.csv", [
            ["name", "latitude (deg)", "longitude (deg)", "1", "2", "3", "4", "5"],
            ["Washakie County", "43.8356", "-107.6602", "21902", "6160", "2721", "12917", "18048"],
            ["Platte County", "42.1314", "-104.9676", "16723", "8709", "22584", "12278", "7196"],
            ["Park County", "44.4063", "-109.4153", "14731", "11729", "15562", "7703", "23349"],
            ["Goshen County", "42.0853", "-104.3534", "23266", "16299", "11470", "20107", "21592"],
        ]);
    };

    const onInitialAmountsDownload = () => {
        const result = [];
        for (const [locationName, locationDict] of Object.entries(props.value["initial amounts"])) {
            // Add header
            if (result.length == 0) {
                const T = locationDict["amount (tonne)"].length;
                const row = ["name", "latitude (deg)", "longitude (deg)"];
                for (let t = 0; t < T; t++) {
                    row.push(t + 1);
                }
                result.push(row);
            }

            // Add content row
            const row = [locationName, locationDict["latitude (deg)"], locationDict["longitude (deg)"]];
            locationDict["amount (tonne)"].forEach(el => {
                row.push(el);
            });
            result.push(row);
        }
        exportToCsv(`Initial amounts - ${props.name}`, result);
    };

    let description = "Not initially available";
    const nCenters = Object.keys(props.value["initial amounts"]).length;
    if (nCenters > 0) {
        description = `${nCenters} collection centers`;
    }

    return (
        <>
            <Section title={props.name} />
            <Card>
                <Form>
                    <h1>General information</h1>
                    <FileInputRow
                        value={description}
                        label="Initial amounts"
                        tooltip="A dictionary mapping the name of each location to its description (see below). If this product is not initially available, this key may be omitted."
                        accept=".csv"
                        onFile={onInitialAmountsFile}
                        onDownload={onInitialAmountsDownload}
                        onClear={onInitialAmountsClear}
                        onTemplate={onInitialAmountsTemplate}
                    />
                    <TextInputRow
                        label="Acquisition cost"
                        unit="$/tonne"
                        tooltip="The cost to acquire one tonne of this product from collection centers. Does not apply to plant outputs."
                        value={props.value["acquisition cost ($/tonne)"]}
                        onChange={v => onChange("acquisition cost ($/tonne)", v)}
                        validate="float"
                    />

                    <h1>Disposal</h1>
                    <TextInputRow
                        label="Disposal cost"
                        unit="$/tonne"
                        tooltip="The cost to dispose of one tonne of this product at a collection center, without further processing. Does not apply to plant outputs."
                        value={props.value["disposal cost ($/tonne)"]}
                        onChange={v => onChange("disposal cost ($/tonne)", v)}
                        validate="float"
                    />
                    <TextInputRow
                        label="Disposal limit"
                        unit="tonne"
                        tooltip="The maximum amount of this product that can be disposed of across all collection centers, without further processing."
                        value={props.value["disposal limit (tonne)"]}
                        onChange={v => onChange("disposal limit (tonne)", v)}
                        validate="float"
                    />

                    <h1>Transportation</h1>
                    <TextInputRow
                        label="Transportation cost"
                        unit="$/km/tonne"
                        tooltip="The cost to transport this product."
                        value={props.value["transportation cost ($/km/tonne)"]}
                        onChange={v => onChange("transportation cost ($/km/tonne)", v)}
                        validate="float"
                    />
                    <TextInputRow
                        label="Transportation energy"
                        unit="J/km/tonne"
                        tooltip="The energy required to transport this product."
                        value={props.value["transportation energy (J/km/tonne)"]}
                        onChange={v => onChange("transportation energy (J/km/tonne)", v)}
                        validate="float"
                    />
                    <DictInputRow
                        label="Transportation emissions"
                        unit="J/km/tonne"
                        tooltip="A dictionary mapping the name of each greenhouse gas, produced to transport one tonne of this product along one kilometer, to the amount of gas produced (in tonnes)."
                        keyPlaceholder="Emission name"
                        value={props.value["transportation emissions (J/km/tonne)"]}
                        onChange={v => onChange("transportation emissions (J/km/tonne)", v)}
                        validate="float"
                    />
                </Form>
            </Card>
        </>
    );
};

function exportToCsv(filename, rows) {
    var processRow = function (row) {
        var finalVal = "";
        for (var j = 0; j < row.length; j++) {
            var innerValue = row[j] === null ? "" : row[j].toString();
            if (row[j] instanceof Date) {
                innerValue = row[j].toLocaleString();
            }
            var result = innerValue.replace(/"/g, '""');
            if (result.search(/("|,|\n)/g) >= 0) result = '"' + result + '"';
            if (j > 0) finalVal += ",";
            finalVal += result;
        }
        return finalVal + "\n";
    };

    var csvFile = "";
    for (var i = 0; i < rows.length; i++) {
        csvFile += processRow(rows[i]);
    }

    var blob = new Blob([csvFile], { type: "text/csv;charset=utf-8;" });
    if (navigator.msSaveBlob) {
        // IE 10+
        navigator.msSaveBlob(blob, filename);
    } else {
        var link = document.createElement("a");
        if (link.download !== undefined) {
            var url = URL.createObjectURL(blob);
            link.setAttribute("href", url);
            link.setAttribute("download", filename);
            link.style.visibility = "hidden";
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
    }
}

export default ProductBlock;