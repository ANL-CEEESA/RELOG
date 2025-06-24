export interface CircularPlant {
    id: string;
    x: number;
    y: number;
    inputs: string[];
    outputs: Record<string, number>;


}

export interface CircularProduct { 
    id: string;
    x: number;
    y: number;
}

export interface CircularData {
    plants: Record<string, CircularPlant>;

    products: Record<string, CircularProduct>;


}