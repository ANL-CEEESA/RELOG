/*
 * RELOG: Supply Chain Analysis and Optimization
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import Header from "./Header";

import "tabulator-tables/dist/css/tabulator.min.css";
import "../Common/Forms/Tables.css";
import Footer from "./Footer";
import React, { useState, useRef } from "react";
import { defaultPlant, defaultProduct, defaultCenter } from "./defaults";
import PipelineBlock from "./PipelineBlock";
import "@xyflow/react/dist/style.css";
import {
  PlantNode,
  CenterNode,
  ProductNode,
  RELOGScenario,
} from "./CircularData";
import { idText } from "typescript";

declare global {
  interface Window {
    nextX: number;
    nextY: number;
  }
}

const Default_Scenario: RELOGScenario = {
  Parameters: { version: "1.0" },
  Plants: {},
  Products: {},
  Centers: {},
};

const CaseBuilder = () => {
  const nextUid = useRef(1);
  const [scenario, setScenario] = useState<RELOGScenario>(Default_Scenario);

  const onClear = () => {};
  const onSave = () => {};
  const onLoad = () => {};

  const nextNodePosition = (): [number, number] => {
    if (window.nextX === undefined) window.nextX = 15;
    if (window.nextY === undefined) window.nextY = 15;

    window.nextY += 60;
    if (window.nextY >= 500) {
      window.nextY = 15;
      window.nextX += 150;
    }
    return [window.nextX, window.nextY];
  };

  const promptName = (): string | undefined => {
    const name = prompt("Name");
    if (!name || name.length === 0) return;
    return name;
  };

  type EntityKey = "Plants" | "Products" | "Centers";

  const onAddNode = (type: EntityKey) => {
    setScenario((prevData) => {
      const name = promptName();
      if (!name) return prevData;

      const uid = `${name}-$${nextUid.current++}`;
      const [x, y] = nextNodePosition();

      let newNode;
      if (type === "Plants") {
        newNode = { ...defaultPlant, uid, name, x, y };
      } else if (type === "Products") {
        newNode = { ...defaultProduct, uid, name, x, y };
      } else {
        newNode = { ...defaultCenter, uid, name, x, y };
      }
      return {
        ...prevData,
        [type]: {
          ...prevData[type],
          [uid]: newNode,
        },
      } as RELOGScenario;
    });
  };

  const onSetCenterInput = (centerName: string, productName: string) => {
    setScenario((prev) => {
      const center = prev.Centers[centerName];
      if (!center) return prev;
      return {
        ...prev,
        centers: {
          ...prev.Centers,
          [centerName]: { ...center, input: productName },
        },
      };
    });
  };

  const onSetPlantInput = (plantName: string, productName: string) => {
    setScenario((prevData: RELOGScenario) => {
      const plant = prevData.Plants[plantName];

      if (!plant) return prevData;

      const updatedPlant: PlantNode = {
        ...plant,

        inputs: plant.inputs.includes(productName)
          ? plant.inputs
          : [...plant.inputs, productName],
      };

      return {
        ...prevData,

        plants: {
          ...prevData.Plants,

          [plantName]: updatedPlant,
        },
      };
    });
  };

  const onAddPlantOutput = (plantName: string, productName: string) => {
    setScenario((prevData) => {
      const plant = prevData.Plants[plantName];
      if (!plant) return prevData;

      const newOutputs = plant.outputs.includes(productName)
        ? plant.outputs
        : [...plant.outputs, productName];

      return {
        ...prevData,
        plants: {
          ...prevData.Plants,
          [plantName]: {
            ...plant,
            outputs: newOutputs,
          },
        },
      };
    });
  };

  const onAddCenterOutput = (centerName: string, productName: string) => {
    setScenario((prev) => {
      const center = prev.Centers[centerName];
      if (!center) return prev;

      const updatedOutputs = [...center.output, productName];
      return {
        ...prev,
        centers: {
          ...prev.Centers,
          [centerName]: { ...center, output: updatedOutputs },
        },
      };
    });
  };

  const onMoveNode = (type: EntityKey, id: string, x: number, y: number) => {
    setScenario((prevData) => {
      const nodesMap = prevData[type];
      const node = nodesMap[id];
      if (!node) return prevData;

      return {
        ...prevData,
        [type]: {
          ...nodesMap,
          [id]: { ...node, x, y },
        },
      } as RELOGScenario;
    });
  };

  const onRemoveNode = (type: EntityKey, id: string) => {
    setScenario((prevData) => {
      const nodesMap = { ...prevData[type] };
      delete nodesMap[id];

      return {
        ...prevData,
        [type]: nodesMap,
      };
    });
  };

  const onRenamePlant = (uniqueId: string, newName: string) => {
    setScenario((prev) => {
      const plant = prev.Plants[uniqueId];
      if (!plant) return prev;
      const next = {
        ...prev,
        plants: {
          ...prev.Plants,
          [uniqueId]: { ...plant, name: newName },
        },
      };
      return next;
    });
  };

  const onRenameProduct = (uniqueId: string, newName: string) => {
    setScenario((prev) => {
      const product = prev.Products[uniqueId];
      if (!product) return prev;
      const next = {
        ...prev,
        products: {
          ...prev.Products,
          [uniqueId]: { ...product, name: newName },
        },
      };
      return next;
    });
  };

  const onRenameCenter = (uniqueId: string, newName: string) => {
    setScenario((prev) => {
      const center = prev.Centers[uniqueId];
      if (!center) return prev;
      const next = {
        ...prev,
        centers: {
          ...prev.Centers,
          [uniqueId]: { ...center, name: newName },
        },
      };
      return next;
    });
  };

  return (
    <div>
      <Header onClear={onClear} onSave={onSave} onLoad={onLoad} />
      <div className="content">
        <div id="contentBackground">
          <div id="content">
            <PipelineBlock
              onAddPlant={() => onAddNode("Plants")}
              onAddProduct={() => onAddNode("Products")}
              onMovePlant={(id, x, y) => onMoveNode("Plants", id, x, y)}
              onMoveProduct={(id, x, y) => onMoveNode("Products", id, x, y)}
              plants={scenario.Plants}
              products={scenario.Products}
              onSetPlantInput={onSetPlantInput}
              onAddPlantOutput={onAddPlantOutput}
              onAddCenter={() => onAddNode("Centers")}
              onAddCenterInput={onSetCenterInput}
              onAddCenterOutput={onAddCenterOutput}
              onMoveCenter={(id, x, y) => onMoveNode("Centers", id, x, y)}
              centers={scenario.Centers}
              onRemovePlant={(id) => onRemoveNode("Plants", id)}
              onRemoveProduct={(id) => onRemoveNode("Products", id)}
              onRemoveCenter={(id) => onRemoveNode("Centers", id)}
              onRenamePlant={onRenamePlant}
              onRenameProduct={onRenameProduct}
              onRenameCenter={onRenameCenter}
            />
          </div>
        </div>
      </div>
      <Footer />
    </div>
  );
};

export default CaseBuilder;
