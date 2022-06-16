import * as React from 'react';
import ReactDOM from 'react-dom/client';
import { Token, Tokens } from '../SelectToken/Token';
import { CollateralType } from './CollateralType';
import SelectTokenModal from '../SelectToken/SelectTokenModal';
import SelectCollateralModal from './SelectCollateralModal';
import { useDisclosure } from "@chakra-ui/hooks"
import {
    Box,
    Container,
    FormControl,
    Heading,
    FormLabel,
    Select,
    Button,
    ButtonGroup,
    Text,
    VStack,
    Input,
} from '@chakra-ui/react';
import {
    FaInfoCircle,
} from 'react-icons/fa';
import {
    ChevronDownIcon
} from '@chakra-ui/icons';

interface OpenLoanProps {
    handleOpenLoanConfirm: (token: Token) => any;
}

const OpenLoan: React.FC<OpenLoanProps> = (props) => {
    const [token0, setToken0] = React.useState<Token>(Tokens[0]);
    const [token1, setToken1] = React.useState<Token>(Tokens[0]);
    const [tokenNumber, setTokenNumber] = React.useState(0);
    const [collateralType, setCollateralType] = React.useState<CollateralType>(CollateralType.None);
    const [collateralButtonText, setCollateralButtonText] = React.useState("Select collateral type");
    const { 
        isOpen: isOpenSelectToken, 
        onOpen: onOpenSelectToken, 
        onClose: onCloseSelectToken 
    } = useDisclosure()
    const { 
        isOpen: isOpenSelectCollateral, 
        onOpen: onOpenSelectCollateral, 
        onClose: onCloseSelectCollateral
    } = useDisclosure()

    const handleTokenSelected = (token: Token, tokenNumber: number) => {
        console.log("selected token" + tokenNumber + " " + token.symbol);
        if (tokenNumber==0) {
            setToken0(token);
        } else {
            setToken1(token);
        }
        onCloseSelectToken();
    }

    const handleCollateralSelected = (type: CollateralType) => {
        console.log("selected collateral type " + CollateralType[type]);
        setCollateralType(type);
        setCollateralButtonText(getCollateralTypeButtonText(type));
        onCloseSelectCollateral();
    }

    function onOpenToken0() {
        setTokenNumber(0);
        onOpenSelectToken();
    }

    function onOpenToken1() {
        setTokenNumber(1);
        onOpenSelectToken();
    }

    function getCollateralTypeButtonText(collateralType: CollateralType) {
        switch(collateralType) {
            case CollateralType.None:
                return "Select collateral type";
            case CollateralType.LPToken:
                return "Liquidity pool tokens";
            case CollateralType.Token0:
                return token0.symbol;
            case CollateralType.Token1:
                return token1.symbol;
            case CollateralType.Both:
                return "Both";
            default:
                return "Select collateral type";
        }
        return "";
    }

    return (
        <Container>
            <Box borderRadius={'2xl'} bg={'#1d2c52'} maxW='450px' boxShadow='dark-lg'>
                <FormControl p='10px 15px 0px 15px' boxShadow='lg'>
                    <VStack>
                        <Heading color={'#e2e8f0'} marginBottom={'25px'}>Open Your Loan</Heading>
                        <FormLabel variant='openLoan'>Select a Token Pair</FormLabel>
                        <Container>
                            <Container w='50%' display='inline-block' ><Select id='token0' onClick={onOpenToken0} color={'#e2e8f0'} placeholder='Select a token'/></Container>
                            <Container w='50%' display='inline-block' ><Select id='token1' onClick={onOpenToken1} color={'#e2e8f0'} placeholder='Select a token'/></Container>
                            <SelectTokenModal handleTokenSelected={handleTokenSelected} isOpen={isOpenSelectToken} onClose={onCloseSelectToken} tokenNumber={tokenNumber}></SelectTokenModal>
                        </Container>
                        <Container textAlign='center'>
                            <ButtonGroup variant='loanInfo' display='inline-block' size='tiny' >
                                <Button leftIcon={<FaInfoCircle />}>
                                    <Text pr='5px'>MaxLTV</Text>
                                    <Text >--%</Text>
                                </Button>
                                <Button leftIcon={<FaInfoCircle />}>
                                    <Text pr='5px'>Liquidation Threshold</Text>
                                    <Text >--%</Text>
                                </Button>
                                <Button leftIcon={<FaInfoCircle />}>
                                <Text pr='5px'>Liquidation Penalty</Text>
                                    <Text >--%</Text>
                                </Button>
                            </ButtonGroup>
                        </Container>
                        <FormLabel variant='openLoan'>Your Loan Amount</FormLabel>
                        <Input variant='outline' placeholder='0'></Input>
                        <Container display='inline-flex' p='0' m='0'>
                            <FormLabel variant='openLoanFit' pr='20px' m='0'>Your Collateral</FormLabel>
                            <Button variant='collateral' size='tiny' h='20px' rightIcon={<ChevronDownIcon />} onClick={onOpenSelectCollateral}>
                                <Text ml='4px'>{collateralButtonText}</Text>
                            </Button>
                            <SelectCollateralModal 
                                token0={token0} 
                                token1={token1} 
                                handleCollateralSelected={handleCollateralSelected} 
                                isOpen={isOpenSelectCollateral} 
                                onClose={onCloseSelectCollateral}
                            />
                        </Container>
                        <Input variant='outline' placeholder='0'></Input>
                        <Container p='20px' />
                        <Container textAlign='right'>
                            <Text variant='loanInfoRight' pr='5px'>Interest Rate</Text>
                            <Text variant='loanInfoRight' >--%</Text>
                        </Container>
                        <Container p='0 0 5px 0'>
                            <Button variant='insuffBal' >Confirm</Button>
                        </Container>
                    </VStack>
                </FormControl>
            </Box >
        </Container>
    )
}

export default OpenLoan