export interface CircularPlant {
    uid: string;
    name: string;
    x: number;
    y: number;
    inputs: string[];
    outputs: string[];


}

export interface CircularProduct { 
    uid: string;
    name: string;
    x: number;
    y: number;
}

export interface CircularData {
    plants: Record<string, CircularPlant>;
    products: Record<string, CircularProduct>;
    centers: Record<string, CircularCenter>;


}

export interface CircularCenter {
    uid: string;
    name: string;
    x: number;
    y: number;

    //single input, multiple outputs 
    input?: string;
    output: string[];
}