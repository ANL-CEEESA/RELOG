import React from 'react';
import './index.css';
import PipelineBlock from './PipelineBlock';
import ParametersBlock from './ParametersBlock';
import ProductBlock from './ProductBlock';
import PlantBlock from './PlantBlock';
import ButtonRow from './ButtonRow';
import Button from './Button';


const InputPage = () => {
    return <>
        <PipelineBlock />
        <ParametersBlock />
        <ProductBlock name="Battery" />
        <ProductBlock name="Nickel" />
        <ProductBlock name="Metal casing" />
        <PlantBlock name="Battery Recycling Plant" />
        <ButtonRow>
            <Button label="Load" />
            <Button label="Save" />
        </ButtonRow>
    </>
}

export default InputPage;