import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import Header from './Header';
import InputPage from './InputPage';
import Footer from './Footer';

ReactDOM.render(
  <React.StrictMode>
    <Header />
    <div id="content">
      <InputPage />
    </div>
    <Footer />
  </React.StrictMode>,
  document.getElementById('root')
);
