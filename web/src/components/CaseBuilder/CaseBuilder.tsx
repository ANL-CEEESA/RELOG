/*
 * RELOG: Supply Chain Analysis and Optimization
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import Header from "./Header";

import "tabulator-tables/dist/css/tabulator.min.css";
import "../Common/Forms/Tables.css";
import Footer from "./Footer";
import React, { useState } from "react";
import {CircularData} from "./CircularData";
import { defaultPlant, defaultProduct, defaultCenter } from "./defaults";
import PipelineBlock from "./PipelineBlock";
import '@xyflow/react/dist/style.css';
import { CircularPlant, CircularCenter} from "./CircularData";
declare global {
    interface Window {
      nextX: number;
      nextY: number;
    }
  }

const CaseBuilder = () => {
  const [circularData, setCircularData] = useState<CircularData> ( {
  plants: {},
  products: {},
  centers: {}

});
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

  const promptName = (prevData:CircularData): string | undefined => {
    const name = prompt("Name");
    if (!name || name.length ===0) return;
    if (name in prevData.products || name in prevData.plants) return;
    return name;

  };

  const onAddPlant = () => {
    setCircularData((prevData) => {
      const id = promptName(prevData);
      if (id ===undefined) return prevData;
      const [x,y] = randomPosition();
      const newData: CircularData = {
         ...prevData,
         plants: {
          ...prevData.plants,
          [id]: {
            ...defaultPlant,
            x,
            y,
          }
         }
        };
     return newData;
    });
  };

  const onAddProduct = () => {
    setCircularData((prevData) => {
      const id = promptName(prevData);
      if (id ===undefined) return prevData;
      const [x,y] = randomPosition();
      const newData: CircularData = {
         ...prevData,
         products: {
          ...prevData.products,
          [id]: {
            ...defaultProduct,
            x,
            y,
          }
         }
        };
     return newData;
    });

  };

  const onAddCenter = () => {
  setCircularData(prev => {
    const name = prompt("Center name");
    if (!name || name in prev.centers) return prev;

    const [x,y] = randomPosition();
    const next = {
      ...prev,
      centers: {
        ...prev.centers,
        [name]: { ...defaultCenter, id:name, x, y, outputs: []}

      }
    };
    return next;
   
  });
};

const onSetCenterInput = (centerName: string, productName: string) => {
  setCircularData((prev) => {
    const center = prev.centers[centerName];
    if (!center) return prev;
    return {
      ...prev,
      centers: {
        ...prev.centers,
        [centerName]: { ...center, input: productName},
      },
    };
  });
};

 const onSetPlantInput = (plantName: string, productName: string) => {

  setCircularData((prevData: CircularData) => {

    const plant = prevData.plants[plantName];

    if (!plant) return prevData; 
 
    const updatedPlant: CircularPlant = {

      ...plant,

      inputs: plant.inputs.includes(productName)

        ? plant.inputs

        : [...plant.inputs, productName],

    };
 
    return {

      ...prevData,

      plants: {

        ...prevData.plants,

        [plantName]: updatedPlant,

      },

    };

  });

};



const onAddPlantOutput = (plantName: string, productName: string) => {
  setCircularData(prevData => {
    const plant = prevData.plants[plantName];
    if (!plant) return prevData;
 
    // Build a new array of outputs, avoiding duplicates
    const newOutputs = plant.outputs.includes(productName)
      ? plant.outputs
      : [...plant.outputs, productName];
 
    // Return updated state with outputs as an array
    return {
      ...prevData,
      plants: {
        ...prevData.plants,
        [plantName]: {
          ...plant,
          outputs: newOutputs,
        },
      },
    };
  });
};

const onAddCenterOutput = (centerName: string, productName: string) => {
  setCircularData((prev) => {
    const center = prev.centers[centerName];
    if (!center) return prev;
  
    const updatedOutputs = [...center.output, productName];
  return {
    ...prev,
    centers: {
      ...prev.centers,
      [centerName]: { ...center, output: updatedOutputs},
    },
  };
});
};

 

  const onMovePlant = (plantName: string, x: number, y: number) => {
    setCircularData((prevData: CircularData): CircularData => {
      const newData: CircularData ={ ...prevData};
      if (!newData.plants[plantName]) return prevData;
      newData.plants[plantName].x =x;
      newData.plants[plantName].y =y;
      return newData;
    });

  };

  const onMoveProduct = (productName: string, x: number, y: number) => {
     setCircularData((prevData: CircularData): CircularData => {
      const newData: CircularData ={ ...prevData};
      const product = newData.products[productName];
      if (!product) return prevData;
      product.x = x;
      product.y =y;
      return newData;
    });

  };

  const onMoveCenter = (centerName: string, x: number, y: number) => {
    setCircularData((prev) => {
      const center = prev.centers[centerName];
      if (!center) return prev;
      return {
        ...prev,
        centers: {
          ...prev.centers,
          [centerName]: { ...center,x,y},
        },
      };
    });
  };

  const onRemovePlant = (plantName: string) => {
    setCircularData(prev => {
      const next = { ...prev };
      delete next.plants[plantName];

      return next;
    });
  };
   const onRemoveProduct = (productName: string) => {
    setCircularData(prev => {
      const next = { ...prev };
      delete next.products[productName];

      return next;
    });
  };

   const onRemoveCenter = (centerName: string) => {
    setCircularData(prev => {
      const next = { ...prev };
      delete next.centers[centerName];

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
            plants={circularData.plants}
            products={circularData.products}
            onSetPlantInput={onSetPlantInput}
            onAddPlantOutput={onAddPlantOutput}
            onAddCenter= {onAddCenter}
            onAddCenterInput={onSetCenterInput}
            onAddCenterOutput={onAddCenterOutput}
            onMoveCenter={onMoveCenter}
            centers={circularData.centers}
            onRemovePlant={onRemovePlant}
            onRemoveProduct={onRemoveProduct}
            onRemoveCenter={onRemoveCenter}
          />
    </div> 
</div> 
      </div>
      <Footer />
    </div>
  );
};

export default CaseBuilder;
