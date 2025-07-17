/*
 * RELOG: Supply Chain Analysis and Optimization
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import Header from "./Header";

import "tabulator-tables/dist/css/tabulator.min.css";
import "../Common/Forms/Tables.css";
import Footer from "./Footer";
import React, { useState,useRef } from "react";
import { defaultPlant, defaultProduct, defaultCenter } from "./defaults";
import PipelineBlock from "./PipelineBlock";
import '@xyflow/react/dist/style.css';
import { PlantNode, CenterNode, ProductNode, RELOGScenario} from "./CircularData";

declare global {
    interface Window {
      nextX: number;
      nextY: number;
    }
  }

  const Default_Scenario: RELOGScenario = {
    Parameters: { version: "1.0"},
    Plants: {},
    Products: {},
    Centers: {},
  };

const CaseBuilder = () => {
  const nextUid= useRef(1);
  const [scenario, setScenario] = useState<RELOGScenario>(Default_Scenario);

  const onClear = () => {};
  const onSave = () => {};
  const onLoad = () => {};
  

  

  const randomPosition = (): [number,number] => {
    if (window.nextX === undefined) window.nextX = 15;
    if (window.nextY === undefined) window.nextY = 15;

    window.nextY +=60;
    if (window.nextY >=500) {
      window.nextY = 15;
      window.nextX += 150;

    }
    return [window.nextX, window.nextY];

  };

  const promptName = (prevData:RELOGScenario): string | undefined => {
    const name = prompt("Name");
    if (!name || name.length ===0) return;
    return name;

  };

  const onAddPlant = () => {
    setScenario((prevData) => {
      const name = promptName(prevData);
      if (name ===undefined) return prevData;

      const uid = `${name}-${nextUid.current++}`;
      const [x,y] = randomPosition();
      const newData: RELOGScenario = {
         ...prevData,
         Plants: {
          ...prevData.Plants,
          [uid]: {
            ...defaultPlant,
            x,
            y,
            name,
            uid
          }
         }
        };
     return newData;
    });
  };

  const onAddProduct = () => {
    setScenario((prevData) => {
      const name = promptName(prevData);
      if (name ===undefined) return prevData;
      const uid = `${name}-${nextUid.current++}`;
      const [x,y] = randomPosition();
      const newData: RELOGScenario = {
         ...prevData,
         Products: {
          ...prevData.Products,
          [uid]: {
            ...defaultProduct,
            x,
            y,
            name,
            uid
          }
         }
        };
     return newData;
    });

  };

  const onAddCenter = () => {
    setScenario((prevData) => {
      const name = promptName(prevData);
      if (name ===undefined) return prevData;
      const uid = `${name}-${nextUid.current++}`;
      const [x,y] = randomPosition();
      const newData: RELOGScenario = {
         ...prevData,
         Centers: {
          ...prevData.Centers,
          [uid]: {
            ...defaultCenter,
            x,
            y,
            name,
            uid
          }
         }
        };
     return newData;
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
        [centerName]: { ...center, input: productName},
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
  setScenario(prevData => {
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
      [centerName]: { ...center, output: updatedOutputs},
    },
  };
});
};

 

  const onMovePlant = (plantName: string, x: number, y: number) => {
    setScenario((prevData: RELOGScenario): RELOGScenario => {
      const newData: RELOGScenario ={ ...prevData};
      if (!newData.Plants[plantName]) return prevData;
      newData.Plants[plantName].x =x;
      newData.Plants[plantName].y =y;
      return newData;
    });

  };

  const onMoveProduct = (productName: string, x: number, y: number) => {
     setScenario((prevData: RELOGScenario): RELOGScenario => {
      const newData: RELOGScenario ={ ...prevData};
      const product = newData.Products[productName];
      if (!product) return prevData;
      product.x = x;
      product.y =y;
      return newData;
    });

  };

  const onMoveCenter = (centerName: string, x: number, y: number) => {
    setScenario((prev) => {
      const center = prev.Centers[centerName];
      if (!center) return prev;
      return {
        ...prev,
        centers: {
          ...prev.Centers,
          [centerName]: { ...center,x,y},
        },
      };
    });
  };

  const onRemovePlant = (plantName: string) => {
    setScenario(prev => {
      const next = { ...prev };
      delete next.Plants[plantName];

      return next;
    });
  };
   const onRemoveProduct = (productName: string) => {
    setScenario(prev => {
      const next = { ...prev };
      delete next.Products[productName];

      return next;
    });
  };

   const onRemoveCenter = (centerName: string) => {
    setScenario(prev => {
      const next = { ...prev };
      delete next.Centers[centerName];

      return next;
    });
  };

  const onRenamePlant = (uniqueId: string, newName: string) => {
    setScenario(prev => {
      const plant = prev.Plants[uniqueId];
      if (!plant) return prev;
      const next = {
        ...prev,
        plants: {
          ...prev.Plants,
          [uniqueId]: { ...plant, name: newName},
        },
      };
      return next;
    

  });
 };

const onRenameProduct = (uniqueId: string, newName: string) => {
    setScenario(prev => {
      const product = prev.Products[uniqueId];
      if (!product) return prev;
      const next = {
        ...prev,
        products: {
          ...prev.Products,
          [uniqueId]: { ...product, name: newName},
        },
      };
      return next;
  });
};

const onRenameCenter = (uniqueId: string, newName: string) => {
    setScenario(prev => {
      const center = prev.Centers[uniqueId];
      if (!center) return prev;
      const next = {
        ...prev,
        centers: {
          ...prev.Centers,
          [uniqueId]: { ...center, name: newName},
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
            onAddPlant={onAddPlant}
            onAddProduct={onAddProduct}
            onMovePlant={onMovePlant}
            onMoveProduct={onMoveProduct}
            plants={scenario.Plants}
            products={scenario.Products}
            onSetPlantInput={onSetPlantInput}
            onAddPlantOutput={onAddPlantOutput}
            onAddCenter= {onAddCenter}
            onAddCenterInput={onSetCenterInput}
            onAddCenterOutput={onAddCenterOutput}
            onMoveCenter={onMoveCenter}
            centers={scenario.Centers}
            onRemovePlant={onRemovePlant}
            onRemoveProduct={onRemoveProduct}
            onRemoveCenter={onRemoveCenter}
            onRenamePlant = {onRenamePlant}
            onRenameProduct = {onRenameProduct}
            onRenameCenter = {onRenameCenter}
          />
    </div> 
</div> 
      </div>
      <Footer />
    </div>
  );
};

export default CaseBuilder;
