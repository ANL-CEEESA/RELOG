import { CircularData, PlantNode, ProductNode, CenterNode } from "./CircularData";

export interface DefaultProduct extends ProductNode{ 
  x: number;
  y: number;
}

export interface DefaultPlant extends PlantNode{
  x: number;
  y: number;
}

export interface DefaultCenter extends PlantNode{
  x: number;
  y: number;
}

export const defaultProduct: DefaultProduct = {
  uid: "",
  name: "",
  x: 0,
  y: 0,
};

export const defaultPlant: PlantNode = {
  uid: "",
  name: "",
  x: 0,
  y: 0,
  inputs : [],
  outputs: [],
};

export const defaultCenter: CenterNode = {
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

