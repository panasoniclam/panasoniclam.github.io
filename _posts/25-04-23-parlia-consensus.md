---
title: Consensus
layout: post
---

Các genesis config liên quan:
ActiveValidatorsLength 
MisdemeanorThreshold
FelonyThreshold
GasLimit

Cơ chế lấy danh sách active validators của Staking smart contract
Ở đầu mỗi epoch, các validator (geth node) sẽ lấy thông tin về danh sách các validators (an address list) được quyền tham gia vào quá trình validate cho epoch hiện tại, danh sách này được chọn ra bởi hàm getValidators() ở Staking smart contract.

Staking smart contract quản lý một danh sách tổng các validator candidates (độ dài N), danh sách này có thể được thay đổi (thêm, xóa, sửa) thông qua cơ chế voting của Governance smart contract. Có thể hiểu danh sách này là danh sách các ứng cử viên có thể trở thành validator. Hàm getValidators() sẽ quyết định các ứng cử viên nào được trở thành validators.

Tham số genesis ActiveValidatorsLength (K) sẽ là độ dài của danh sách mà hàm getValidators() trả về, hay nói cách khác, hàm getValidators() sẽ lấy ra top K trong số N candidates có số lượng stake nhiều nhất. Nếu K > N thì hàm getValidators() sẽ đơn giản trả về danh sách có N phần tử.

Ví dụ:
Tại thời điểm genesis, ta config K = 5 và deploy N = 4 validators cho chain. Do K > N nên length(getValidators()) = 4
Tại thời điểm bất kì sau đó, cộng đồng thông qua Governance đã thêm mới 2 candidates để tăng cường tính resilience và decentralization cho chain, khi đó K = 5 < N = 4 + 2 = 6 nên length(getValidators()) = 5, điều này có nghĩa là candidate xếp hạng thứ 6 không được chọn làm validator cho đến khi candidate đó được xếp hạng từ vị trí thứ 5 trở lên (lý do candidate đó sau này được xếp hạng ở vị trí cao hơn có thể là do số lượng stake trở nên nhiều hơn hoặc do những candidate xếp hạng cao hơn đã bị gỡ khỏi danh sách)

Cơ chế chọn validator đóng block của Parlia consensus
Ở đầu mỗi epoch, sau khi đã lấy được thông tin danh sách các active validators cho epoch hiện tại, Parlia consensus sẽ giúp các validators đồng thuận với nhau về việc validator nào sẽ chịu trách nhiệm đóng block nào.

Thuật toán chọn validator trong Parlia consensus:

Các validators sẽ luân phiên nhau đóng block (round-robin) theo công thức:

chosenValidator = blockNumber % K

Trong đó:

chosenValidator: index của validator được chọn để validate trong mảng validators (ví dụ address[] validators = [0x123, 0x456, 0x789], chosenValidator = 2 => validators[chosenValidator]  = 0x789)
blockNumber: block number hiện tại

Các validators có quyền tranh nhau đóng block, validator được xác định dựa trên công thức round robin sẽ có quyền ưu tiên trước nhất (in-turn validation), các validator khác sẽ phải đợi một khoảng thời gian trước khi được quyền tham gia đóng block (out-of-turn validation). Điều này nhằm giải quyết trường hợp validator được chọn không hoạt động (go offline) và lượt đóng block này nên được giao cho validator khác. Khi out-of-turn validation diễn ra, validator giành được quyền đóng block từ validator được chọn sẽ slash validator được chọn đó (đánh dấu), nếu một validator có số lần bị slash trên một mức threshold nhất định sẽ bị phạt (penalize): lớn hơn MisdemeanorThreshold sẽ bị mất phần gas fee của epoch đó, lớn hơn FelonyThreshold sẽ bị xóa khỏi danh sách candidates ở Staking smart contract (go to jail), đồng nghĩa với việc không còn là ứng cử viên trở thành validator nữa.

Gọi D là Khoảng cách tối thiểu giữa 2 lần validate gần nhất của một validator, D luôn luôn bằng K/2. 
Ví dụ:
K = 6 => D = 6/2 = 3
Khi chọn validator để đóng block 10, những validator đã đóng block 9, 8 sẽ không có quyền tham gia đóng block. Validator đã đóng block 7 và những validator còn lại có thể tham gia tranh nhau đóng block 10.

Như vậy, tại một thời điểm, chỉ có K/2 + 1 validator tham gia tranh nhau đóng block.

Các trường hợp validator ngưng hoạt động (go offline)

Như đã nói ở trên, tại một thời điểm, chỉ có K/2 + 1 validators tham gia tranh nhau đóng block và K/2 - 1 validator còn lại không tham gia. Từ đây, ta có thể suy ra 2 trường hợp:
Mạng lưới sẽ không thể tạo ra block mới nếu có nhiều hơn hoặc bằng K/2 + 1 validators ngưng hoạt động.
Ngược lại, nếu có ít hơn K/2 + 1 validators ngưng hoạt động, mạng lưới vẫn sẽ tiếp tục sinh ra block mới (vẫn hoạt động bình thường).

Backup validators

Như đã nói ở trên, Staking smart contract quản lý danh sách các validator candidates và các validators sẽ cập nhật lại danh sách các active validators tại thời điểm đầu epoch. Nhờ vào cơ chế slashing, các validators không hoạt động trong một khoảng thời gian dài sẽ bị phát hiện và loại bỏ khỏi danh sách validator candidates, thay đổi này sẽ chỉ có hiệu lực vào epoch tiếp theo (khi mà các validators hiện tại cập nhật danh sách active validators tại thời điểm đầu epoch). Như vậy ta có thể kết luận như sau: Nếu số lượng validators ngưng hoạt động sao cho vẫn đảm bảo cho mạng lưới có thể tạo ra block mới (để đi đến epoch tiếp theo, thời điểm mà danh sách active validators được cập nhật lại) thì cơ chế backup validators mới có thể hoạt động, những validator candidates còn lại sẽ được nâng hạng và trở thành những validators mới.

TPS


Transactions per second (TPS) là chỉ số thường được dùng để đo tốc độ của một hệ thống giao dịch. Trong ngữ cảnh blockchain, TPS được tính bằng công thức:

TPS = (number of tx in a block)/(block time)

Số lượng transaction trong một block được tính bằng công thức:

Number of tx in a block = (gas limit)/(transaction gas cost)

Trong blockchain, transaction sẽ được đo lường bằng đơn vị gas, transaction được đo lường với càng nhiều gas thì biểu hiện transaction đó tốn càng nhiều tài nguyên để thực thi. Như vậy, để tính được số lượng transaction trong một block, ta cần giả định các transaction đều hao phí một lượng gas như nhau.

Một transaction đơn giản nhất sẽ hao phí 21000 gas, từ đây ta có thể giả định tất cả các transaction đều ở dạng đơn giản nhất để tính ra được Max TPS. Ngoài ra, ta có thể giả định các transaction trên mạng lưới phần lớn sẽ là các transaction transfer của token dạng chuẩn ERC20, dạng transaction này sẽ hao phí khoảng 45000 gas, ta có thể lấy kết quả TPS của giả định này để làm Estimated TPS.

Ví dụ:
Ethereum:
Gas limit: 30 000 000 gas
Block time: 15 seconds
Max TPS = (30 000 000 / 21000) / 15 ~= 95
Estimated TPS = (30 000 000 / 45000) / 15 ~= 44

Binance Smart Chain:
Gas limit: 140 000 000 gas
Block time: 3 seconds
Max TPS = (140 000 000 / 21000) / 3 ~= 2222
Estimated TPS = (140 000 000 / 45000) / 3 ~= 1037

Omni Chain:
Gas limit: 40 000 000 gas
Block time: 3 seconds
Max TPS = (40 000 000 / 21000) / 3 ~= 634
Estimated TPS = (40 000 000 / 45000) / 3 ~= 296 

Từ công thức trên, ta có thể dễ dàng nhận ra, để tăng chỉ số TPS, ta chỉ cần tăng gas limit và giảm block time. Vậy tại sao các dự án chain đó không set mức gas limit ở mức cao hơn, hay set block time ở mức thấp hơn? Phần tiếp theo về Time to finality sẽ trả lời câu hỏi này.

Time to finality

Trên thực tế, để đo lường tốc độ của một chain, ngoài việc cân nhắc chỉ số TPS, chỉ số về Time to finality (TTF) cũng không kém phần quan trọng. TTF là thời gian đạt được Finality của một transaction, chỉ số này càng thấp thì transaction sẽ càng nhanh chóng đạt được Finality. Ta luôn mong muốn chỉ số TPS cao cùng với chỉ số TTF thấp. Chỉ số TPS có thể dễ dàng cải thiện được thông qua việc tăng gas limit, vertical scaling,..., nhưng chỉ số TTF khó có thể cải thiện được hơn, nên thường chỉ số TTF sẽ được ưu tiên đem ra bàn cân để so sánh các chain với nhau.

Chỉ số TPS và TTF thường sẽ đối lập với nhau, nếu cải thiện một bên thì có thể tác động xấu đến bên còn lại. Ví dụ, nếu ta cải thiện TPS bằng cách tăng lượng gas limit, chỉ số throughput sẽ tăng, một block có thể chứa nhiều transaction hơn, điều này cũng đồng nghĩa với việc mạng lưới đang thay đổi rất nhanh, các nodes trong hệ thống phân tán có thể không theo kịp với nhau, không đồng thuận về trạng thái của mạng lưới hiện tại, dẫn đến reorganization (forks). Khi đó dù cho chỉ số TPS có cao cỡ nào mà tỉ lệ các transactions bị revert cao thì chỉ số TPS đó hoàn toàn vô nghĩa.


TPS và TTF trong Omni Chain

Công thức tính TTF của BAS:

TTF = (2/3*K + 1) * (block time)

Hiện tại, config genesis GasLimit của Omni Chain đang để mặc định là 40 000 000.

Omni Chain:
Gas limit: 40 000 000 gas
Block time: 3 seconds
Max TPS = (40 000 000 / 21000) / 3 ~= 634
Estimated TPS = (40 000 000 / 45000) / 3 ~= 296 

Ta có thể cải thiện chỉ số TPS và TTF bằng cách:

Tăng gas limit, từ 40 000 000 lên 140 000 000 (giống Binance)
Các validator nodes được deploy ở gần nhau nhất có thể
Giảm tính phi tập trung bằng cách cố định số lượng nhỏ validators, ActiveValidatorsLength = 7

Với những config trên, ta sẽ có chỉ số TPS và TTF của Omni Chain như sau:

Max TPS = (140 000 000 / 21000) / 3 ~= 2222 txs/second
Estimated TPS = (140 000 000 / 45000) / 3 ~= 1037 txs/second
TTF = (2/3*7 + 1) * 3 = 15 seconds













Tài liệu:
https://www.ankr.com/docs/affiliated-chains/bnb-sidechain/staking/

A detailed guide to blockchain speed | TPS vs. time to finality | Solana, Aptos, Fantom & Avalanche compared — which chain has sub-second finality? | by Pontem Network | Medium

https://www.ankr.com/docs/affiliated-chains/bnb-sidechain/architecture/fast-finality/
Time to Finality. A Technical Promenade, part 3 | by Alephium | Medium












