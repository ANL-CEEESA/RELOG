import React, { useState, useRef } from "react";

import "./index.css";
import PipelineBlock from "./PipelineBlock";
import ParametersBlock from "./ParametersBlock";
import ProductBlock from "./ProductBlock";
import PlantBlock from "./PlantBlock";
import Button from "./Button";
import Header from "./Header";
import Footer from "./Footer";
import { defaultData, defaultPlant, defaultProduct } from "./defaults";
import { randomPosition } from "./PipelineBlock";
import { exportData, importData } from "./export";
import { generateFile } from "./csv";

const setDefaults = (actualDict, defaultDict) => {
  for (const [key, defaultValue] of Object.entries(defaultDict)) {
    if (!(key in actualDict)) {
      if (typeof defaultValue === "object") {
        actualDict[key] = { ...defaultValue };
      } else {
        actualDict[key] = defaultValue;
      }
    }
  }
};

const cleanDict = (dict, defaultDict) => {
  for (const key of Object.keys(dict)) {
    if (!(key in defaultDict)) {
      delete dict[key];
    }
  }
};

const fixLists = (dict, blacklist, stringify) => {
  for (const [key, val] of Object.entries(dict)) {
    if (blacklist.includes(key)) continue;
    if (Array.isArray(val)) {
      // Replace constant lists by a single number
      let isConstant = true;
      for (let i = 1; i < val.length; i++) {
        if (val[i - 1] !== val[i]) {
          isConstant = false;
          break;
        }
      }
      if (isConstant) dict[key] = val[0];

      // Convert lists to JSON strings
      if (stringify) dict[key] = JSON.stringify(dict[key]);
    }
    if (typeof val === "object") {
      fixLists(val, blacklist, stringify);
    }
  }
};

const InputPage = () => {
  const fileElem = useRef();

  let savedData = JSON.parse(localStorage.getItem("data"));
  if (!savedData) savedData = defaultData;

  let [data, setData] = useState(savedData);

  const save = (data) => {
    localStorage.setItem("data", JSON.stringify(data));
  };

  const promptName = (prevData) => {
    const name = prompt("Name");
    if (!name || name.length === 0) return;
    if (name in prevData.products || name in prevData.plants) return;
    return name;
  };

  const onAddPlant = () => {
    setData((prevData) => {
      const name = promptName(prevData);
      if (name === undefined) return prevData;
      const newData = { ...prevData };
      const [x, y] = randomPosition();
      newData.plants[name] = {
        ...defaultPlant,
        x: x,
        y: y,
      };
      save(newData);
      return newData;
    });
  };

  const onAddProduct = () => {
    setData((prevData) => {
      const name = promptName(prevData);
      if (name === undefined) return prevData;
      const newData = { ...prevData };
      const [x, y] = randomPosition();
      console.log(x, y);
      newData.products[name] = {
        ...defaultProduct,
        x: x,
        y: y,
      };
      save(newData);
      return newData;
    });
  };

  const onRenamePlant = (prevName, newName) => {
    setData((prevData) => {
      const newData = { ...prevData };
      newData.plants[newName] = newData.plants[prevName];
      delete newData.plants[prevName];
      save(newData);
      return newData;
    });
  };

  const onRenameProduct = (prevName, newName) => {
    setData((prevData) => {
      const newData = { ...prevData };
      newData.products[newName] = newData.products[prevName];
      delete newData.products[prevName];
      for (const [, plant] of Object.entries(newData.plants)) {
        if (plant.input === prevName) {
          plant.input = newName;
        }
        let outputFound = false;
        for (const [outputName] of Object.entries(
          plant["outputs (tonne/tonne)"]
        )) {
          if (outputName === prevName) outputFound = true;
        }
        if (outputFound) {
          plant["outputs (tonne/tonne)"][newName] =
            plant["outputs (tonne/tonne)"][prevName];
          delete plant["outputs (tonne/tonne)"][prevName];
        }
      }
      save(newData);
      return newData;
    });
  };

  const onMovePlant = (plantName, x, y) => {
    setData((prevData) => {
      const newData = { ...prevData };
      newData.plants[plantName].x = x;
      newData.plants[plantName].y = y;
      save(newData);
      return newData;
    });
  };

  const onMoveProduct = (productName, x, y) => {
    setData((prevData) => {
      const newData = { ...prevData };
      newData.products[productName].x = x;
      newData.products[productName].y = y;
      save(newData);
      return newData;
    });
  };

  const onRemovePlant = (plantName) => {
    setData((prevData) => {
      const newData = { ...prevData };
      delete newData.plants[plantName];
      save(newData);
      return newData;
    });
  };

  const onRemoveProduct = (productName) => {
    setData((prevData) => {
      const newData = { ...prevData };
      delete newData.products[productName];
      for (const [, plant] of Object.entries(newData.plants)) {
        if (plant.input === productName) {
          delete plant.input;
        }
        let outputFound = false;
        for (const [outputName] of Object.entries(
          plant["outputs (tonne/tonne)"]
        )) {
          if (outputName === productName) outputFound = true;
        }
        if (outputFound) {
          delete plant["outputs (tonne/tonne)"][productName];
        }
      }
      save(newData);
      return newData;
    });
  };

  const onSetPlantInput = (plantName, productName) => {
    setData((prevData) => {
      const newData = { ...prevData };
      newData.plants[plantName].input = productName;
      save(newData);
      return newData;
    });
  };

  const onAddPlantOutput = (plantName, productName) => {
    setData((prevData) => {
      if (productName in prevData.plants[plantName]["outputs (tonne/tonne)"]) {
        return prevData;
      }
      const newData = { ...prevData };
      [
        "outputs (tonne/tonne)",
        "disposal cost ($/tonne)",
        "disposal limit (tonne)",
      ].forEach((key) => {
        newData.plants[plantName][key] = { ...newData.plants[plantName][key] };
        newData.plants[plantName][key][productName] = 0;
      });
      save(newData);
      return newData;
    });
  };

  const onSave = () => {
    generateFile("case.json", JSON.stringify(exportData(data), null, 2));
  };

  const onClear = () => {
    const newData = JSON.parse(JSON.stringify(defaultData));
    setData(newData);
    save(newData);
  };

  const onLoad = (contents) => {
    const newData = importData(JSON.parse(contents));
    setData(newData);
    save(newData);
  };

  const onChange = (val, field1, field2) => {
    setData((prevData) => {
      const newData = { ...prevData };
      if (field2 !== undefined) {
        newData[field1][field2] = val;
      } else {
        newData[field1] = val;
      }
      save(newData);
      return newData;
    });
  };
  let productComps = [];
  for (const [prodName, prod] of Object.entries(data.products)) {
    productComps.push(
      <ProductBlock
        key={prodName}
        name={prodName}
        value={prod}
        onChange={(v) => onChange(v, "products", prodName, v)}
      />
    );
  }

  let plantComps = [];
  for (const [plantName, plant] of Object.entries(data.plants)) {
    plantComps.push(
      <PlantBlock
        key={plantName}
        name={plantName}
        value={plant}
        onChange={(v) => onChange(v, "plants", plantName)}
      />
    );
  }

  const onFileSelected = () => {
    const file = fileElem.current.files[0];
    if (file) {
      const reader = new FileReader();
      reader.addEventListener("load", () => {
        onLoad(reader.result);
      });
      reader.readAsText(file);
    }
    fileElem.current.value = "";
  };

  return (
    <>
      <Header title="Case Builder">
        <Button label="Clear" onClick={onClear} />
        <Button label="Load" onClick={(e) => fileElem.current.click()} />
        <Button label="Save" onClick={onSave} />
        <input
          type="file"
          ref={fileElem}
          accept=".json"
          style={{ display: "none" }}
          onChange={onFileSelected}
        />
      </Header>
      <div id="content">
        <PipelineBlock
          onAddPlant={onAddPlant}
          onAddPlantOutput={onAddPlantOutput}
          onAddProduct={onAddProduct}
          onMovePlant={onMovePlant}
          onMoveProduct={onMoveProduct}
          onRenamePlant={onRenamePlant}
          onRenameProduct={onRenameProduct}
          onSetPlantInput={onSetPlantInput}
          onRemovePlant={onRemovePlant}
          onRemoveProduct={onRemoveProduct}
          plants={data.plants}
          products={data.products}
        />
        <ParametersBlock
          value={data.parameters}
          onChange={(v) => onChange(v, "parameters")}
        />
        {productComps}
        {plantComps}
      </div>
      <Footer />
    </>
  );
};

export default InputPage;
