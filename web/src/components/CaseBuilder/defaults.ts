import { CircularData, CircularPlant, CircularProduct, CircularCenter } from "./CircularData";

export interface DefaultProduct extends CircularProduct{ 
  x: number;
  y: number;
}

export interface DefaultPlant extends CircularPlant{
  x: number;
  y: number;
}

export interface DefaultCenter extends CircularPlant{
  x: number;
  y: number;
}

export const defaultProduct: DefaultProduct = {
  uid: "",
  name: "",
  x: 0,
  y: 0,
};

export const defaultPlant: CircularPlant = {
  uid: "",
  name: "",
  x: 0,
  y: 0,
  inputs : [],
  outputs: [],
};

export const defaultCenter: CircularCenter = {
  uid: "",
  name: "",
  x: 0,
  y: 0,
  output: [],
};

export const DefaultData: CircularData = {
  products: {},
  plants: {},
  centers: {}
};

