//
//  AgentHighCases.m
//  Indy-demo
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <Indy/Indy.h>
#import "TestUtils.h"
#import "PoolUtils.h"
#import "AgentUtils.h"
#import "WalletUtils.h"
#import "SignusUtils.h"
#import "AnoncredsUtils.h"
#import "NSDictionary+JSON.h"
#import "NSString+Validation.h"
#import "NSArray+JSON.h"

@interface AgentHignCases : XCTestCase

@end

@implementation AgentHignCases

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAgentListerWorksWithIndyAgentConnect
{
    [TestUtils cleanupStorage];
    NSError *ret;
    NSString *poolName = [TestUtils pool];
    
    // 1. create and open wallet
    IndyHandle walletHandle = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:poolName
                                                                  xtype:nil
                                                                 handle:&walletHandle];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed ");

    // 2. create DID
    NSString *did;
    NSString *verKey;
    NSString *pubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:walletHandle
                                                                       seed:nil
                                                                   outMyDid:&did
                                                                outMyVerkey:&verKey
                                                                    outMyPk:&pubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed ");
    
    // WARNING: You may need to change port to 9802, because 9801 is already used in pool. Here and in other similar places too.
    // 3. listen
    NSString *endpoint = [TestUtils endpoint];
    
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                       connectionCallback:nil
                                          messageCallback:nil
                                        outListenerHandle:&listenerHandle];
     XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithWalletHandle() failed ");
    
    // 4. Add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:-1
                                                       walletHandle:walletHandle
                                                                did:did];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed ");
    
    // 5. Store their did from parts
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:walletHandle
                                                                      theirDid:did
                                                                       theirPk:pubKey
                                                                   theirVerkey:verKey
                                                                      endpoint:endpoint];
     XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed ");
    
    // 6. Connect
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:0
                                                walletHandle:walletHandle
                                                   senderDid:did
                                                 receiverDid:did
                                             messageCallback:nil
                                         outConnectionHandle:nil];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed ");
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:walletHandle];
    [TestUtils cleanupStorage];
}

// MARK: - Agent connect

- (void)testAgentConnectWorksForRemoteData
{
    [TestUtils cleanupStorage];
    NSString *poolName = [TestUtils pool];
    NSError *ret;
    
    // 1. create and open pool ledger config
    IndyHandle poolHandle = 0;
    ret = [[PoolUtils sharedInstance] createAndOpenPoolLedgerWithPoolName:poolName
                                                               poolHandle:&poolHandle];
    XCTAssertEqual(ret.code, Success, @"PoolUtils::createAndOpenPoolLedgerWithPoolName() failed ");
    
    // 2. Create listener's wallet
    IndyHandle listenerWallet = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:poolName
                                                                  xtype:nil
                                                                 handle:&listenerWallet];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed for listenerWallet");
    
    // 3. Create trustees's wallet
    IndyHandle trusteeWallet = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:poolName
                                                                  xtype:nil
                                                                 handle:&trusteeWallet];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed for trusteeWallet");
    
    // 4. Obtain listener Did
    NSString *listenerDid;
    NSString *listenerVerKey;
    NSString *listenerPubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:listenerWallet
                                                                       seed:nil
                                                                   outMyDid:&listenerDid
                                                                outMyVerkey:&listenerVerKey
                                                                    outMyPk:&listenerPubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for listenerDid");
    
     // 5. Obtain trustee Did
    NSString *trusteeDid;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:trusteeWallet
                                                                       seed:[TestUtils trusteeSeed]
                                                                   outMyDid:&trusteeDid
                                                                outMyVerkey:nil
                                                                    outMyPk:nil];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for trusteeDid");

    // 6. Build nym request
    NSString *listenerNymJson;
    ret = [[LedgerUtils sharedInstance] buildNymRequestWithSubmitterDid:trusteeDid
                                                              targetDid:listenerDid
                                                                 verkey:listenerVerKey
                                                                  alias:nil
                                                                   role:nil
                                                             outRequest:&listenerNymJson];
    XCTAssertEqual(ret.code, Success, @"LedgerUtils::buildNymRequestWithSubmitterDid() failed for listenerNymJson");
    XCTAssertTrue([listenerNymJson isValid], @"invalid listenerNymJson: %@",listenerNymJson);
    
    // 7. Sign and submit nym request
    NSString *listenerNymResponse;
    ret = [[LedgerUtils sharedInstance] signAndSubmitRequestWithPoolHandle:poolHandle
                                                              walletHandle:trusteeWallet
                                                              submitterDid:trusteeDid
                                                               requestJson:listenerNymJson
                                                           outResponseJson:&listenerNymResponse];
    XCTAssertEqual(ret.code, Success, @"LedgerUtils::signAndSubmitRequestWithPoolHandle() failed for listenerNymJson");
    XCTAssertTrue([listenerNymResponse isValid], @"invalid listenerNymResponse: %@",listenerNymResponse);
    
    // 8. Sign and submit listener attribute request
    NSString *endpoint = [TestUtils endpoint];
    NSString *rawJson = [NSString stringWithFormat:@"{\"endpoint\":{\"ha\":\"%@\", \"verkey\":\"%@\"}}", endpoint, listenerPubKey];
    NSString *listenerAttribRequest;
    ret = [[LedgerUtils sharedInstance] buildAttribRequestWithSubmitterDid:listenerDid
                                                                 targetDid:listenerDid
                                                                      hash:nil
                                                                       raw:rawJson
                                                                       enc:nil
                                                                resultJson:&listenerAttribRequest];
    
    // 9. Sign and submit attribute request
    NSString *litenerAttribResponse;
    ret = [[LedgerUtils sharedInstance] signAndSubmitRequestWithPoolHandle:poolHandle
                                                              walletHandle:listenerWallet
                                                              submitterDid:listenerDid
                                                               requestJson:listenerAttribRequest outResponseJson:&litenerAttribResponse];
    XCTAssertEqual(ret.code, Success, @"LedgerUtils::signAndSubmitRequestWithPoolHandle() failed for listenerAttribRequest");
    XCTAssertTrue([litenerAttribResponse isValid], @"invalid litenerAttribResponse: %@",litenerAttribResponse);
    
    
    
    // 10. listen
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                       connectionCallback:nil
                                          messageCallback:nil
                                        outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithWalletHandle() failed");
    
    
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:poolHandle
                                                       walletHandle:listenerWallet
                                                                did:listenerDid];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 11. connect
    IndyHandle connectHandle = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:poolHandle
                                                walletHandle:trusteeWallet
                                                   senderDid:trusteeDid
                                                 receiverDid:listenerDid
                                             messageCallback:nil
                                         outConnectionHandle:&connectHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed");
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[AgentUtils sharedInstance] closeConnection:connectHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:listenerWallet];
    [[WalletUtils sharedInstance] closeWalletWithHandle:trusteeWallet];
    [[PoolUtils sharedInstance] closeHandle:poolHandle];
    [TestUtils cleanupStorage];
}

- (void)testAgentConnectWorksForAllDataInWalletPresent
{
    [TestUtils cleanupStorage];
    NSError *ret;
    
    // 1. obtain wallet handle
    IndyHandle walletHandle;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&walletHandle];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed");
    
    // 2. Obtain did
    NSString *seed = @"indy_agent_connect_works_for_aaa";
    NSString *did;
    NSString *verKey;
    NSString *pubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:walletHandle
                                                                       seed:seed
                                                                   outMyDid:&did
                                                                outMyVerkey:&verKey
                                                                    outMyPk:&pubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed");
    
    // 3. store their did from parts
    NSString *endpoint = @"127.0.0.1:9700";
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:walletHandle
                                                                      theirDid:did
                                                                       theirPk:pubKey
                                                                   theirVerkey:verKey
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // In Rust there is some temporary code which will be replaced with indy_agent_listen
    // 4. listen
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                       connectionCallback:nil
                                          messageCallback:nil
                                        outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::listenWithEndpoint() failed");
    
    // 4. Add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:-1
                                                       walletHandle:walletHandle
                                                                did:did];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 5. connect
    IndyHandle connectHandle = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:0
                                                walletHandle:walletHandle
                                                   senderDid:did
                                                 receiverDid:did
                                             messageCallback:nil
                                         outConnectionHandle:&connectHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed");
    
    [[AgentUtils sharedInstance] closeConnection:connectHandle];
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:walletHandle];
    [TestUtils cleanupStorage];
}

// MARK: - Indy agent listen

- (void)testAgentListenWorksForAllDataInWalletPresent
{
    [TestUtils cleanupStorage];
    NSError *ret;
    
    // 1. Obtain pool handle
    IndyHandle poolHandle = 0;
    ret = [[PoolUtils sharedInstance] createAndOpenPoolLedgerWithPoolName:[TestUtils pool]
                                                               poolHandle:&poolHandle];
    XCTAssertEqual(ret.code, Success, @"PoolUtils::createAndOpenPoolLedgerWithPoolName() failed");
    
    // 2. Obtain listener wallet handle
    IndyHandle listenerWallet;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&listenerWallet];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed for listener");
    
    // 3. Obtain sender wallet handle
    IndyHandle senderWallet = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&senderWallet];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed for sender");
    
    // 4. Obtain listener did
    NSString *listenerDid;
    NSString *listenerVerKey;
    NSString *listenerPubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:listenerWallet
                                                                       seed:[TestUtils trusteeSeed]
                                                                   outMyDid:&listenerDid
                                                                outMyVerkey:&listenerVerKey
                                                                    outMyPk:&listenerPubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for listener");
    
    // 5. Obtain sender did
    NSString *senderDid;
    NSString *senderVerKey;
    NSString *senderPubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:listenerWallet
                                                                       seed:nil
                                                                   outMyDid:&senderDid
                                                                outMyVerkey:&senderVerKey
                                                                    outMyPk:&senderPubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for sender");
    
    // 6. Store their did from parts
    NSString *endpoint = [TestUtils endpoint];
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:listenerWallet
                                                                      theirDid:senderDid
                                                                       theirPk:senderPubKey
                                                                   theirVerkey:senderVerKey
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 7. Listen
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                      connectionCallback:nil
                                         messageCallback:nil
                                       outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithWalletHandle() failed");
    
    // 8. Add identity
    
    [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                   poolHandle:poolHandle
                                                 walletHandle:listenerWallet
                                                          did:listenerDid];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 9. store their did
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:senderWallet
                                                                      theirDid:listenerDid
                                                                       theirPk:listenerPubKey
                                                                   theirVerkey:listenerVerKey
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 10. Connect
    
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:poolHandle
                                                walletHandle:senderWallet
                                                   senderDid:senderDid
                                                 receiverDid:listenerDid
                                             messageCallback:nil
                                         outConnectionHandle:nil];
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:listenerWallet];
    [[WalletUtils sharedInstance] closeWalletWithHandle:senderWallet];
    [[PoolUtils sharedInstance] closeHandle:poolHandle];
    [TestUtils cleanupStorage];
}

- (void)testAgentListenWorksForGetSenderDataFromLedger
{
    [TestUtils cleanupStorage];
    NSError *ret;
    NSString *poolName = [TestUtils pool];
    
    // 1. create and open pool ledger
    
    IndyHandle poolHandle = 0;
    ret = [[PoolUtils sharedInstance] createAndOpenPoolLedgerWithPoolName:poolName
                                                                 poolHandle:&poolHandle];
    XCTAssertEqual(ret.code, Success, @"PoolUtils::createAndOpenPoolLedgerWithPoolName() failed");
    
    // 2. create and open trustee wallet
    
    IndyHandle trusteeWallet = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:poolName
                                                                  xtype:nil
                                                                 handle:&trusteeWallet];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed for trusteeWallet");
    IndyHandle listenerWallet = trusteeWallet;
    
    // 3. create and open sender wallet
    
    IndyHandle senderWallet = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:poolName
                                                                  xtype:nil
                                                                 handle:&senderWallet];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed for senderWallet");
    
    // 4. create and store trusteeDid
    NSString *trusteeDid;
    NSString *trusteeVerkey;
    NSString *trusteePk;
    
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:trusteeWallet
                                                                       seed:[TestUtils trusteeSeed]
                                                                   outMyDid:&trusteeDid
                                                                outMyVerkey:&trusteeVerkey
                                                                    outMyPk:&trusteePk];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for trusteeDid");
    
    // 5. create and store senderDid
    NSString *senderDid;
    NSString *senderVerkey;
    NSString *senderPk;
    
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:senderWallet
                                                                       seed:[TestUtils trusteeSeed]
                                                                   outMyDid:&senderDid
                                                                outMyVerkey:&senderVerkey
                                                                    outMyPk:&senderPk];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for senderDid");
    
    // 6. create and store listenerDid
    NSString *listenerDid;
    NSString *listenerVerkey;
    NSString *listenerPk;
    
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:trusteeWallet
                                                                       seed:[TestUtils trusteeSeed]
                                                                   outMyDid:&listenerDid
                                                                outMyVerkey:&listenerVerkey
                                                                    outMyPk:&listenerPk];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for listenerDid");
    
    // 7 Build & submit nym request
    
    NSString *senderNymJson;
    ret = [[LedgerUtils sharedInstance] buildNymRequestWithSubmitterDid:trusteeDid
                                                              targetDid:senderDid
                                                                 verkey:senderVerkey
                                                                  alias:nil
                                                                   role:nil
                                                             outRequest:&senderNymJson];
    XCTAssertEqual(ret.code, Success, @"LedgerUtils::buildNymRequestWithSubmitterDid() failed");
    
    ret = [[LedgerUtils sharedInstance] signAndSubmitRequestWithPoolHandle:poolHandle
                                                              walletHandle:trusteeWallet
                                                              submitterDid:trusteeDid
                                                               requestJson:senderNymJson
                                                           outResponseJson:nil];
    XCTAssertEqual(ret.code, Success, @"LedgerUtils::signAndSubmitRequestWithPoolHandle() failed for senderNymJson");
    
    // 8. Build & submit attribute request
    NSString *raw = [NSString stringWithFormat:@"{\"endpoint\":{\"ha\":\"%@\", \"verkey\":\"%@\"}}",[TestUtils endpoint], senderPk];
    NSString *senderAttribJson;
    ret = [[LedgerUtils sharedInstance] buildAttribRequestWithSubmitterDid:senderDid
                                                                 targetDid:senderDid
                                                                      hash:nil
                                                                       raw:raw
                                                                       enc:nil
                                                                resultJson:&senderAttribJson];
     XCTAssertEqual(ret.code, Success, @"LedgerUtils::buildAttribRequestWithSubmitterDid() failed");
    
    ret = [[LedgerUtils sharedInstance] signAndSubmitRequestWithPoolHandle:poolHandle
                                                              walletHandle:senderWallet
                                                              submitterDid:senderDid
                                                               requestJson:senderAttribJson
                                                           outResponseJson:nil];
     XCTAssertEqual(ret.code, Success, @"LedgerUtils::signAndSubmitRequestWithPoolHandle() failed for  senderAttribJson");
    
    // 9. listen
    
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:[TestUtils endpoint]
                                      connectionCallback:nil
                                         messageCallback:nil
                                       outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenForEndpoint() failed");
    
    // 10. add identity
    
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:poolHandle
                                                       walletHandle:listenerWallet
                                                                did:listenerDid];
    
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 11. store their did from parts
    
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:senderWallet
                                                                      theirDid:listenerDid
                                                                       theirPk:listenerPk
                                                                   theirVerkey:listenerVerkey
                                                                      endpoint:[TestUtils endpoint]];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 12. connect
    
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:poolHandle
                                                walletHandle:senderWallet
                                                   senderDid:senderDid
                                                 receiverDid:listenerDid
                                             messageCallback:nil
                                         outConnectionHandle:nil];
    
    // 13. Close
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:listenerWallet];
    [[WalletUtils sharedInstance] closeWalletWithHandle:senderWallet];
    [[PoolUtils sharedInstance] closeHandle:poolHandle];
    
    [TestUtils cleanupStorage];
}

- (void)testAgentListenWorksForPassedOnConnectCallback
{
    [TestUtils cleanupStorage];
    
    NSError *ret;
    NSString *poolName = [TestUtils pool];
    NSString *msg = @"New Connection";
    
    // 1. create and open pool ledger
    
    IndyHandle poolHandle = 0;
    ret = [[PoolUtils sharedInstance] createAndOpenPoolLedgerWithPoolName:poolName
                                                                 poolHandle:&poolHandle];
    XCTAssertEqual(ret.code, Success, @"PoolUtils::createAndOpenPoolLedgerWithPoolName() failed");

    // 2. create and open wallet
    IndyHandle walletHandle = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:poolName
                                                                  xtype:nil
                                                                 handle:&walletHandle];
     XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed");
    
    //3. obtain my did
    
    NSString *did;
    NSString *verkey;
    NSString *pubKey;
    
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:walletHandle
                                                                       seed:nil
                                                                   outMyDid:&did
                                                                outMyVerkey:&verkey
                                                                    outMyPk:&pubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed");
    
    // 4. store their did from parts
    
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:walletHandle
                                                                      theirDid:did
                                                                       theirPk:pubKey
                                                                   theirVerkey:verkey
                                                                      endpoint:[TestUtils endpoint]];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 5. listen
    
    // connection callback
    XCTestExpectation* listenerConnectionCompletionExpectation = [[ XCTestExpectation alloc] initWithDescription: @"listener completion finished"];
    __block NSString *connectionCallbackIsCalled;
    void (^connectionCallback)(IndyHandle, IndyHandle) = ^(IndyHandle xListenerHandle, IndyHandle xConnectionHandle) {
        connectionCallbackIsCalled = msg;
        NSLog(@"AgentHighCases::testAgentListenWorksForPassedOnConnectCallback:: listener's connectionCallback triggered.");
        [listenerConnectionCompletionExpectation fulfill];
    };
    
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:[TestUtils endpoint]
                                      connectionCallback:connectionCallback
                                         messageCallback:nil
                                       outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenForEndpoint() failed");
    
    // 6. add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:poolHandle
                                                       walletHandle:walletHandle
                                                                did:did];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 7. connect
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:poolHandle
                                                walletHandle:walletHandle
                                                   senderDid:did
                                                 receiverDid:did
                                             messageCallback:nil
                                         outConnectionHandle:nil];
    
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed");
    
    
    [self waitForExpectations: @[listenerConnectionCompletionExpectation] timeout:[TestUtils defaultTimeout]];
    XCTAssertTrue([msg isEqualToString:connectionCallbackIsCalled], @"conenction callback is not called!");
    
    // 8. close everything
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:walletHandle];
    [[PoolUtils sharedInstance] closeHandle:poolHandle];
    [TestUtils cleanupStorage];
}

- (void)testAgentListenWorksForPassedOnMessageCallback
{
    [TestUtils cleanupStorage];
    
    NSError *ret;
    NSString *poolName = [TestUtils pool];
    NSString *msg = @"Message from client";
    
    // 1. create and open pool ledger
    
    IndyHandle poolHandle = 0;
    ret = [[PoolUtils sharedInstance] createAndOpenPoolLedgerWithPoolName:poolName
                                                                 poolHandle:&poolHandle];
    XCTAssertEqual(ret.code, Success, @"PoolUtils::createAndOpenPoolLedgerWithPoolName() failed");
    
    // 2. create and open wallet
    IndyHandle walletHandle = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:poolName
                                                                  xtype:nil
                                                                 handle:&walletHandle];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed");
    
    //3. obtain my did
    
    NSString *did;
    NSString *verkey;
    NSString *pubKey;
    
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:walletHandle
                                                                       seed:nil
                                                                   outMyDid:&did
                                                                outMyVerkey:&verkey
                                                                    outMyPk:&pubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed");
    
    // 4. store their did from parts
    
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:walletHandle
                                                                      theirDid:did
                                                                       theirPk:pubKey
                                                                   theirVerkey:verkey
                                                                      endpoint:[TestUtils endpoint]];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 5. listen
    
    XCTestExpectation* messageFromClientCompletionExpectation = [[ XCTestExpectation alloc] initWithDescription: @"listener completion finished"];
    __block NSString *clientMessage;
    // message from client callback
    void (^messageFromClientCallback)(IndyHandle, NSString *) = ^(IndyHandle xConnectionHandle, NSString * message) {
        clientMessage = message;
        NSLog(@"AgentHighCases::testAgentSendWorksForAllDataInWalletPresent::messageFromClientCallback triggered with message: %@", message);
        [messageFromClientCompletionExpectation fulfill];
    };
    
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:[TestUtils endpoint]
                                      connectionCallback:nil
                                         messageCallback:messageFromClientCallback
                                       outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenForEndpoint() failed");
    
    // 6. add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:poolHandle
                                                       walletHandle:walletHandle
                                                                did:did];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 7. connect
    IndyHandle connectionHandle = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:poolHandle
                                                walletHandle:walletHandle
                                                   senderDid:did
                                                 receiverDid:did
                                             messageCallback:nil
                                         outConnectionHandle:&connectionHandle];
    
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed");
    
    // 8. send message
    
    ret = [[AgentUtils sharedInstance] sendWithConnectionHandler:connectionHandle
                                                         message:msg];
    XCTAssertEqual(ret.code,Success, @"AgentUtils::sendWithConnectionHandler failed");
    
    [self waitForExpectations: @[messageFromClientCompletionExpectation] timeout:[TestUtils defaultTimeout]];
    XCTAssertTrue([clientMessage isEqualToString:msg], @"wrong clientMessage");

    
    // 8. close everything
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[AgentUtils sharedInstance] closeListener:connectionHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:walletHandle];
    [[PoolUtils sharedInstance] closeHandle:poolHandle];
    [TestUtils cleanupStorage];
}


// MARK: - Add identity

- (void)testAgentAddIdentityWorks
{
    [TestUtils cleanupStorage];
    NSError *ret;
    NSString *endpoint = [TestUtils endpoint];
    
    // 1. Create and open receiver's wallet
    IndyHandle receiverWallet = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&receiverWallet];
     XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed for receiverWallet");
    
    // 2. listen
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                       connectionCallback:nil
                                          messageCallback:nil
                                        outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithEndpoint() failed");
    
    // 3. Create and store receiver's did
    NSString *receiverDid;
    NSString *receiverVerkey;
    NSString *receiverPk;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:receiverWallet
                                                                       seed:nil
                                                                   outMyDid:&receiverDid
                                                                outMyVerkey:&receiverVerkey
                                                                    outMyPk:&receiverPk];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for receiverDid");
    
    
    // 4. Add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:-1
                                                       walletHandle:receiverWallet
                                                                did:receiverDid];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:receiverWallet
                                                                      theirDid:receiverDid
                                                                       theirPk:receiverPk
                                                                   theirVerkey:receiverVerkey
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    IndyHandle connectionHandle = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:-1
                                                walletHandle:receiverWallet
                                                   senderDid:receiverDid
                                                 receiverDid:receiverDid
                                             messageCallback:nil
                                         outConnectionHandle:&connectionHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed");
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[AgentUtils sharedInstance] closeConnection:connectionHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:receiverWallet];
    [TestUtils cleanupStorage];
}

- (void)testAgentAddIdentityWorksForMultipleKeys
{
    [TestUtils cleanupStorage];
    NSError *ret;
    NSString *endpoint = [TestUtils endpoint];
    
    // 1. Create and open receiver's wallet
    IndyHandle receiverWallet = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&receiverWallet];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed for receiverWallet");
    
    // 2. listen
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                       connectionCallback:nil
                                          messageCallback:nil
                                        outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithEndpoint() failed");
    
    // 3. Create and store receiver DID 1
    NSString *receiverDid1;
    NSString *receiverVerkey1;
    NSString *receiverPk1;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:receiverWallet
                                                                       seed:nil
                                                                   outMyDid:&receiverDid1
                                                                outMyVerkey:&receiverVerkey1
                                                                    outMyPk:&receiverPk1];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for receiverDid 1");
    
    // 4. Create and store receiver DID 2
    NSString *receiverDid2;
    NSString *receiverVerkey2;
    NSString *receiverPk2;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:receiverWallet
                                                                       seed:nil
                                                                   outMyDid:&receiverDid2
                                                                outMyVerkey:&receiverVerkey2
                                                                    outMyPk:&receiverPk2];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for receiverDid 2");
    
    // 5. Add identities
    NSMutableArray *receiverDids = [NSMutableArray new];
    [receiverDids addObject:receiverDid1];
    [receiverDids addObject:receiverDid2];
    
    for (NSString *did in receiverDids)
    {
        ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                             poolHandle:-1
                                                           walletHandle:receiverWallet
                                                                    did:did];
        XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed for DID: %@", did);
    }
    
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:receiverWallet
                                                                      theirDid:receiverDid1
                                                                       theirPk:receiverPk1
                                                                   theirVerkey:receiverVerkey1
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:receiverWallet
                                                                      theirDid:receiverDid2
                                                                       theirPk:receiverPk2
                                                                   theirVerkey:receiverVerkey2
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 6. Connect with DID 1
    IndyHandle connectHandle1 = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:-1
                                                walletHandle:receiverWallet
                                                   senderDid:receiverDid1
                                                 receiverDid:receiverDid1
                                             messageCallback:nil
                                         outConnectionHandle:&connectHandle1];
     XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed for DID 1");
    
     // 6. Connect with DID 2
    IndyHandle connectHandle2 = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:-1
                                                walletHandle:receiverWallet
                                                   senderDid:receiverDid2
                                                 receiverDid:receiverDid2
                                             messageCallback:nil
                                         outConnectionHandle:&connectHandle2];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed for DID 2");
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[AgentUtils sharedInstance] closeConnection:connectHandle1];
    [[AgentUtils sharedInstance] closeConnection:connectHandle2];
    [[WalletUtils sharedInstance] closeWalletWithHandle:receiverWallet];
    [TestUtils cleanupStorage];
}

// MARK: - Remove identity

-(void)testAgentRemoveIdentityWorks
{
    [TestUtils cleanupStorage];
    NSString *endpoint = [TestUtils endpoint];
    NSError *ret;
    
    // 1. Obtain receiver's wallet handle
    IndyHandle receiverWalletHandle = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&receiverWalletHandle];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed");
    
    // 2. Listen
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                       connectionCallback:nil messageCallback:nil outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithEndpoint() failed");
    
    // 3. Create and store receiver's DID
    NSString *receiverDid;
    NSString *receiverPk;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:receiverWalletHandle
                                                                       seed:nil
                                                                   outMyDid:&receiverDid
                                                                outMyVerkey:nil
                                                                    outMyPk:&receiverPk];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for receiverDid 2");
    
    // 4. Add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:-1
                                                       walletHandle:receiverWalletHandle
                                                                did:receiverDid];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed for receiverDid 2");
    
    // 5. remove identity
    ret = [[AgentUtils sharedInstance] removeIdentity:receiverDid
                                       listenerHandle:listenerHandle
                                         walletHandle:receiverWalletHandle];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::removeIdentity() failed");
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:receiverWalletHandle];

    [TestUtils cleanupStorage];
}

// MARK: - Agent send

- (void)testAgentSendWorksForAllDataInWalletPresent
{
    [TestUtils cleanupStorage];
    NSError *ret;
    
    // 1. Create and open wallet
    IndyHandle walletHandle = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&walletHandle];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed");
    
    // 2. Obtain did
    NSString *did;
    NSString *verKey;
    NSString *pubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:walletHandle
                                                                       seed:nil
                                                                   outMyDid:&did
                                                                outMyVerkey:&verKey
                                                                    outMyPk:&pubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed");
    
    // 3. Store their did from parts
    NSString *endpoint = [TestUtils endpoint];
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:walletHandle
                                                                      theirDid:did
                                                                       theirPk:pubKey
                                                                   theirVerkey:verKey
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 4. listen
    // connection callback
    XCTestExpectation* listenerConnectionCompletionExpectation = [[ XCTestExpectation alloc] initWithDescription: @"listener completion finished"];
    __block IndyHandle serverToClientConnectId = 0;
    void (^connectionCallback)(IndyHandle, IndyHandle) = ^(IndyHandle xListenerHandle, IndyHandle xConnectionHandle) {
        serverToClientConnectId = xConnectionHandle;
        NSLog(@"AgentHighCases::testAgentSendWorksForAllDataInWalletPresent:: listener's connectionCallback triggered.");
        [listenerConnectionCompletionExpectation fulfill];
    };
    
    XCTestExpectation* messageFromClientCompletionExpectation = [[ XCTestExpectation alloc] initWithDescription: @"listener completion finished"];
    __block NSString *clientMessage;
    // message from client callback
    void (^messageFromClientCallback)(IndyHandle, NSString *) = ^(IndyHandle xConnectionHandle, NSString * message) {
        clientMessage = message;
        NSLog(@"AgentHighCases::testAgentSendWorksForAllDataInWalletPresent::messageFromClientCallback triggered with message: %@", message);
        [messageFromClientCompletionExpectation fulfill];
    };
    
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                           connectionCallback:connectionCallback
                                              messageCallback:messageFromClientCallback
                                            outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithWalletHandle() failed");
    
    // 5. Add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:0
                                                       walletHandle:walletHandle
                                                                did:did];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 6. Connect
    // message from server callback
    
    XCTestExpectation* messageFromServerCompletionExpectation = [[ XCTestExpectation alloc] initWithDescription: @"listener completion finished"];
    __block NSString *serverMessage;
    void (^messageFromServerCallback)(IndyHandle, NSString *) = ^(IndyHandle xConnectionHandle, NSString * message) {
        serverMessage = message;
        NSLog(@"messageFromServerCallback triggered with message: %@", message);
        [messageFromServerCompletionExpectation fulfill];
    };
    
    IndyHandle clientToServerConnectId = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:0
                                                walletHandle:walletHandle
                                                   senderDid:did
                                                 receiverDid:did
                                             messageCallback:messageFromServerCallback
                                         outConnectionHandle:&clientToServerConnectId];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed");
    
    [self waitForExpectations:@[listenerConnectionCompletionExpectation] timeout:[TestUtils defaultTimeout]];
    
    NSString *refClientMessage = @"msg_from_client";
    NSString *refServerMessage = @"msg_from_server";
    
    // 7. Send client message
    ret = [[AgentUtils sharedInstance] sendWithConnectionHandler:clientToServerConnectId
                                                         message:refClientMessage];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::sendWithConnectionHandler() failed for client message");
    
    [self waitForExpectations: @[messageFromClientCompletionExpectation] timeout:[TestUtils defaultTimeout]];
    XCTAssertTrue([clientMessage isEqualToString:refClientMessage], @"wrong clientMessage");
    
    // 8. Send server message
    ret = [[AgentUtils sharedInstance] sendWithConnectionHandler:serverToClientConnectId
                                                         message:refServerMessage];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::sendWithConnectionHandler() failed for server message");
    
    [self waitForExpectations: @[messageFromServerCompletionExpectation] timeout:[TestUtils defaultTimeout]];
    XCTAssertTrue([serverMessage isEqualToString:refServerMessage], @"wrong serverMessage");
    
    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[AgentUtils sharedInstance] closeConnection:clientToServerConnectId];
    [[WalletUtils sharedInstance] closeWalletWithHandle:walletHandle];

    [TestUtils cleanupStorage];
}

// MARK: - Close connection

- (void)testAgentCloseConnectionWorksForOngoing
{
    [TestUtils cleanupStorage];
    NSError *ret;
    
    // 1. Create and open wallet
    IndyHandle walletHandle = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&walletHandle];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed");
    
    // 2. Obtain did
    NSString *did;
    NSString *verKey;
    NSString *pubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:walletHandle
                                                                       seed:nil
                                                                   outMyDid:&did
                                                                outMyVerkey:&verKey
                                                                    outMyPk:&pubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed");
    
    // 3. listen
    NSString *endpoint = [TestUtils endpoint];
    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                           connectionCallback:nil
                                              messageCallback:nil
                                            outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithWalletHandle() failed");
    
    // 4 Add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:-1
                                                       walletHandle:walletHandle
                                                                did:did];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 5. store their did from parts
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:walletHandle
                                                                      theirDid:did
                                                                       theirPk:pubKey
                                                                   theirVerkey:verKey
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 6. connect
    IndyHandle connectionHandle = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:0
                                                walletHandle:walletHandle
                                                   senderDid:did
                                                 receiverDid:did
                                             messageCallback:nil
                                         outConnectionHandle:&connectionHandle];
     XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed");
    
    // 7. close connection
    ret = [[AgentUtils sharedInstance] closeConnection:connectionHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::closeConnection() failed");
    
    // 8. try to send message
    ret = [[AgentUtils sharedInstance] sendWithConnectionHandler:connectionHandle
                                                         message:@""];
    XCTAssertEqual(ret.code, CommonInvalidStructure, @"AgentUtils::sendWithConnectionHandler() returned wrong error code");

    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:walletHandle];

    [TestUtils cleanupStorage];
}

- (void)testAgentCloseConnectionWorksForIncomingConnection
{
    [TestUtils cleanupStorage];
    NSError *ret;
    
    // 1. Create and open wallet
    IndyHandle walletHandle = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&walletHandle];
    XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed");
    
    // 2. Obtain did
    NSString *did;
    NSString *verKey;
    NSString *pubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:walletHandle
                                                                       seed:nil
                                                                   outMyDid:&did
                                                                outMyVerkey:&verKey
                                                                    outMyPk:&pubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed");
    
    // 3. store their did from parts
    NSString *endpoint = [TestUtils endpoint];
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:walletHandle
                                                                      theirDid:did
                                                                       theirPk:pubKey
                                                                   theirVerkey:verKey
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 4. listen
    
    // connection callback
    XCTestExpectation* connectionExpectation = [[ XCTestExpectation alloc] initWithDescription: @"connection completion finished"];

    __block IndyHandle serverToClientConnectId = 0;
    void (^connectionCallback)(IndyHandle, IndyHandle) = ^(IndyHandle xListenerHandle, IndyHandle xConnectionHandle) {
        serverToClientConnectId = xConnectionHandle;
        NSLog(@"connectionCallback triggered.");
        [connectionExpectation fulfill];
    };

    IndyHandle listenerHandle = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                           connectionCallback:connectionCallback
                                              messageCallback:nil
                                            outListenerHandle:&listenerHandle];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithWalletHandle() failed");
    
    // 5. Add Identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandle
                                                         poolHandle:-1
                                                       walletHandle:walletHandle
                                                                did:did];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 6. connect
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:0
                                                walletHandle:walletHandle
                                                   senderDid:did
                                                 receiverDid:did
                                             messageCallback:nil
                                         outConnectionHandle:nil];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::connectWithPoolHandle() failed");
    
    [self waitForExpectations: @[connectionExpectation] timeout:[TestUtils defaultTimeout]];
    
    // 7. close connection
    ret = [[AgentUtils sharedInstance] closeConnection:serverToClientConnectId];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::closeConnection() failed");
    
    // 8. send
    NSString *serverMessage = @"msg_from_server";
    ret = [[AgentUtils sharedInstance] sendWithConnectionHandler:serverToClientConnectId
                                                         message:serverMessage];
    XCTAssertEqual(ret.code, CommonInvalidStructure, @"AgentUtils::sendWithConnectionHandler() returned wrong code");

    [[AgentUtils sharedInstance] closeListener:listenerHandle];
    [[WalletUtils sharedInstance] closeWalletWithHandle:walletHandle];

    [TestUtils cleanupStorage];
}

// MARK: - Agent close listener
- (void)testAgentCloseListenerWorks
{
    [TestUtils cleanupStorage];
    NSError *ret;
    
    // 1. Create and open wallet
    IndyHandle walletHandle = 0;
    ret = [[WalletUtils sharedInstance] createAndOpenWalletWithPoolName:[TestUtils pool]
                                                                  xtype:nil
                                                                 handle:&walletHandle];
     XCTAssertEqual(ret.code, Success, @"WalletUtils::createAndOpenWalletWithPoolName() failed");
    
    // 2. Create and store did
    NSString *did;
    NSString *verKey;
    NSString *pubKey;
    ret = [[SignusUtils sharedInstance] createAndStoreMyDidWithWalletHandle:walletHandle
                                                                       seed:nil
                                                                   outMyDid:&did
                                                                outMyVerkey:&verKey
                                                                    outMyPk:&pubKey];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::createAndStoreMyDid() failed");
    
    // 3. store their did from parts
    NSString *endpoint = [TestUtils endpoint];
    ret = [[SignusUtils sharedInstance] storeTheirDidFromPartsWithWalletHandle:walletHandle
                                                                      theirDid:did
                                                                       theirPk:pubKey
                                                                   theirVerkey:verKey
                                                                      endpoint:endpoint];
    XCTAssertEqual(ret.code, Success, @"SignusUtils::storeTheirDidFromPartsWithWalletHandle() failed");
    
    // 4. Listen
    
    XCTestExpectation* connectionExpectation = [[ XCTestExpectation alloc] initWithDescription: @"connection completion finished"];

    IndyHandle listenerHandler = 0;
    __block IndyHandle serverToClientConenctId = 0;
    ret = [[AgentUtils sharedInstance] listenForEndpoint:endpoint
                                       connectionCallback:^(IndyHandle xListenerHandle, IndyHandle xConnectionHandle)
    {
        serverToClientConenctId = xConnectionHandle;
        [connectionExpectation fulfill];
    }
                                          messageCallback:nil
                                        outListenerHandle:&listenerHandler];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::listenWithEndpoint() failed");
    
    // 5. add identity
    ret = [[AgentUtils sharedInstance] addIdentityForListenerHandle:listenerHandler
                                                         poolHandle:-1
                                                       walletHandle:walletHandle
                                                                did:did];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::addIdentityForListenerHandle() failed");
    
    // 6. connect
    IndyHandle connectHandle = 0;
    ret = [[AgentUtils sharedInstance] connectWithPoolHandle:0
                                                walletHandle:walletHandle
                                                   senderDid:did
                                                 receiverDid:did
                                             messageCallback:nil
                                         outConnectionHandle:&connectHandle];
    
    [self waitForExpectations: @[connectionExpectation] timeout:[TestUtils defaultTimeout]];

    // 7. close Listener
    ret = [[AgentUtils sharedInstance] closeListener: listenerHandler];
    XCTAssertEqual(ret.code, Success, @"AgentUtils::closeListener() failed");
    
    // 8. send
    NSString *serverMessage = @"msg_from_server";
    ret = [[AgentUtils sharedInstance] sendWithConnectionHandler:serverToClientConenctId
                                                         message:serverMessage];
    XCTAssertEqual(ret.code, CommonInvalidStructure, @"AgentUtils::sendWithConnectionHandler() returned wrong error code.");
    
    [[AgentUtils sharedInstance] closeConnection:connectHandle];
    [[AgentUtils sharedInstance] closeListener:listenerHandler];
    [[WalletUtils sharedInstance] closeWalletWithHandle:walletHandle];
    
    [TestUtils cleanupStorage];
}

@end


