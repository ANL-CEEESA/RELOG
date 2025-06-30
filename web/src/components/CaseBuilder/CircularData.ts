export interface CircularPlant {
    id: string;
    x: number;
    y: number;
    inputs: string[];
    outputs: string[];


}

export interface CircularProduct { 
    id: string;
    x: number;
    y: number;
}

export interface CircularData {
    plants: Record<string, CircularPlant>;
    products: Record<string, CircularProduct>;
    centers: Record<string, CircularCenter>;


}

export interface CircularCenter {
    id: string;
    x: number;
    y: number;

    //single input, multiple outputs 
    input?: string;
    output: string[];
}