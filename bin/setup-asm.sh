#export ETH_GAS_PRICE=50000000000
export asm=0x8892a913819088fcbf412dd46355cfb2c93da71f

# == Decimals ==
export dpt=0xb30041ff94fc8fc071029f0abc925a60b5a2059a
export cdc=0x3b5822b3cb38b82ffe49bcb3c6c6483b68b61971
export eth=0x00000000000000000000000000000000000000ee
export dcdc=0xbF2Fb30C4a6f37dCCb08F987814852A5A7b64337
# DPT
# asm.setConfig("decimals", b(dpt), b(decimals[dpt]), "diamonds")
export decimals=$(seth --to-bytes32 $(seth --from-ascii decimals))
# export d18=$(seth --to-bytes32 $(seth --from-ascii 18))
export d18=$(seth --to-bytes32 $(seth --to-uint256 18))
export bDpt=$(seth --to-bytes32 $(seth --to-uint256 $dpt))
export diamonds=$(seth --to-bytes32 $(seth --from-ascii diamonds))

seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $decimals $bDpt $d18 $diamonds

# CDC
# asm.setConfig("decimals", b(cdc), b(decimals[cdc]), "diamonds")
export bCdc=$(seth --to-bytes32 $(seth --to-uint256 $cdc))
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $decimals $bCdc $d18 $diamonds

# ETH
export bEth=$(seth --to-bytes32 $(seth --to-uint256 $eth))
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $decimals $bEth $d18 $diamonds

# DCDC
export bDcdc=$(seth --to-bytes32 $(seth --to-uint256 $dcdc))
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $decimals $bDcdc $d18 $diamonds

# == Price Feed ==
export dptPriceFeed=0xc9faD47Fe77500515de29024C076b6d8D87d423E
export cdcPriceFeed=0x1D2A08e056059a066D98B516BDEab01DFbD0D45F
export ethPriceFeed=0x2Ed2b811A048683E7f2CE00587f73CcfdB86D219

export priceFeed=$(seth --to-bytes32 $(seth --from-ascii priceFeed))

export bDptPriceFeed=$(seth --to-bytes32 $(seth --to-uint256 $dptPriceFeed))
# asm.setConfig("priceFeed", b(dpt), b(feed[dpt]), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $priceFeed $bDpt $bDptPriceFeed $diamonds

export bCdcPriceFeed=$(seth --to-bytes32 $(seth --to-uint256 $cdcPriceFeed))
# asm.setConfig("priceFeed", b(cdc), b(feed[cdc]), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $priceFeed $bCdc $bCdcPriceFeed $diamonds


# DCDC is the same as CDC price feed
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $priceFeed $bDcdc $bCdcPriceFeed $diamonds

export bEthPriceFeed=$(seth --to-bytes32 $(seth --to-uint256 $ethPriceFeed))
# asm.setConfig("priceFeed", b(eth), b(feed[eth]), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $priceFeed $bEth $bEthPriceFeed $diamonds

export bEthPriceFeed=$(seth --to-bytes32 $(seth --to-uint256 $ethPriceFeed))
# asm.setConfig("priceFeed", b(eth), b(feed[eth]), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $priceFeed $bEth $bEthPriceFeed $diamonds


# == Custodians ==
export custodian=0x9556E25F9b4D343ee38348b6Db8691d10fD08A61

export custodians=$(seth --to-bytes32 $(seth --from-ascii custodians))
export bCustodians=$(seth --to-bytes32 $(seth --to-uint256 $custodian))
export bTrue=$(seth --to-bytes32 $(seth --to-uint256 1))

# asm.setConfig("custodians", b(custodian), b(true), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $custodians $bCustodians $bTrue $diamonds

# == payTokens ==
export payTokens=$(seth --to-bytes32 $(seth --from-ascii payTokens))

# asm.setConfig("payTokens", b(dpt), b(true), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $payTokens $bDpt $bTrue $diamonds
# asm.setConfig("payTokens", b(eth), b(true), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $payTokens $bEth $bTrue $diamonds


# == cdcs ==
export cdcs=$(seth --to-bytes32 $(seth --from-ascii cdcs))
# asm.setConfig("cdcs", b(cdc), b(true), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $cdcs $bCdc $bTrue $diamonds

# Это еще не выполнилось
# == dcdcs ==
export dcdcs=$(seth --to-bytes32 $(seth --from-ascii dcdcs))
# asm.setConfig("dcdcs", b(dcdc), b(true), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $dcdcs $bDcdc $bTrue $diamonds

# == dpasses ==
export dpass=0xc6188fBa6b826E45C33d8711155C5f10E0790F4a
export dpasses=$(seth --to-bytes32 $(seth --from-ascii dpasses))
export bDpass=$(seth --to-bytes32 $(seth --to-uint256 $dpass))
# asm.setConfig("dpasses", b(dpass), b(true), "diamonds");
seth send $asm "setConfig(bytes32,bytes32,bytes32,bytes32)" $dpasses $bDpass $bTrue $diamonds
