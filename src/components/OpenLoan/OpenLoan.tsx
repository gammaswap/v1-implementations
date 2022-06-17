import * as React from 'react';
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
    Button,
    ButtonGroup,
    Text,
    VStack,
    Input,
    Image
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
    const [token0Text, setToken0Text] = React.useState("Select token");
    const [token0Icon, setToken0Icon] = React.useState<React.ReactElement>(<Image h='25px'/>);
    const [token1Text, setToken1Text] = React.useState("Select token");
    const [token1Icon, setToken1Icon] = React.useState<React.ReactElement>(<Image h='25px'/>);
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
            setToken0Text(token.symbol);
            setToken0Icon(<Image mr="5px" boxSize='25px' src={token.iconPath}  />)
        } else {
            setToken1(token);
            setToken1Text(token.symbol);
            setToken1Icon(<Image mr="5px" boxSize='25px' src={token.iconPath} />)
        }
        onCloseSelectToken();
        resetCollateralType();
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

    function resetCollateralType() {
        setCollateralType(CollateralType.None);
        setCollateralButtonText(getCollateralTypeButtonText(CollateralType.None));
    }

    return (
        <Container>
            <Box m='auto' borderRadius={'2xl'} bg={'#1d2c52'} maxW='420px' boxShadow='dark-lg'>
                <FormControl p='10px 15px 0px 15px' boxShadow='lg'>
                    <VStack>
                        <Heading color={'#e2e8f0'} marginBottom={'25px'}>Open Your Loan</Heading>
                        <FormLabel variant='openLoan'>Select a Token Pair</FormLabel>
                        <Container display='inline-block'>
                            <Container w='50%' display='inline-grid' >
                                <Button id='token0' variant='select' onClick={onOpenToken0} rightIcon={<ChevronDownIcon />} leftIcon={token0Icon}>
                                    {token0Text}
                                </Button>
                            </Container>
                            <Container w='50%' display='inline-grid' >
                                <Button id='token1' variant='select' onClick={onOpenToken1} rightIcon={<ChevronDownIcon />} leftIcon={token1Icon}>
                                    {token1Text}
                                </Button>
                            </Container>
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
                            <Button variant='select' size='tiny' h='20px' rightIcon={<ChevronDownIcon />} onClick={onOpenSelectCollateral}>
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
                            <Button variant='confirmGrey' >Confirm</Button>
                        </Container>
                    </VStack>
                </FormControl>
            </Box >
        </Container>
    )
}

export default OpenLoan