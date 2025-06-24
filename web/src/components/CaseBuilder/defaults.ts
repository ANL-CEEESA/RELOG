import { CircularPlant, CircularProduct } from "./CircularData";

export interface DefaultProduct extends CircularProduct{ 
  x: number;
  y: number;
}

export interface DefaultPlant extends CircularPlant{
  x: number;
  y: number;
}

export const defaultProduct: DefaultProduct = {
  "id": "",
  x: 0,
  y: 0,
};

export const defaultPlant: CircularPlant = {
  "id": "",
  x: 0,
  y: 0,
  inputs : [],
  outputs: {},
};