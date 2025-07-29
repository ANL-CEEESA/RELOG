import { InitialData, PlantNode, ProductNode, CenterNode } from "./InitialData";



export const defaultProduct: ProductNode = {
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

export const DefaultData: InitialData = {
  products: {},
  plants: {},
  centers: {}
};

