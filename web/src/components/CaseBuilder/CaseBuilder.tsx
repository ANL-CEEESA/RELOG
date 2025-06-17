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
import { defaultPlant, defaultProduct } from "./defaults";
import "../../index.css";
declare global {
    interface Window {
      nextX: number;
      nextY: number;
    }
  }

const CaseBuilder = () => {
  const [circularData, setCircularData] = useState<CircularData> ( {
  plants: {},
  products: {}

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
      if (id ==undefined) return prevData;
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
      if (id ==undefined) return prevData;
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

  return (
    <div>
      <Header onClear={onClear} onSave={onSave} onLoad={onLoad} />
      <div className="content">
        <div id="contentBackground"> 
  <div id="content"> </div> 
</div> 
      </div>
      <Footer />
    </div>
  );
};

export default CaseBuilder;
