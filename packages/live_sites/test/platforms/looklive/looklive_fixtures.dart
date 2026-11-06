// Recorded LOOK Live answers and chat frames, from the reference
// fixtures (fixtures/looklive/, samples S01-S04 recorded 2026-09-27/28,
// chat S05-live and S06-gifts recorded 2026-09-30), trimmed to the
// fields the looklive adapter reads; everything it reads is kept, so
// the parses below pin the recorded answers on every field.

/// The recorded video list, page 1 (three cards, the list's end).
const String videoListP1Body =
    '{"code": 200, "msg": null, "message": null, "data": {"itemList": [{"type": "1", "liveData": {"liveType": 1, "liveId": 134543183, "liveTitle": "ASOT电音电台直播中", "liveCoverUrl": "http://p3.music.126.net/y-H5ttUqsAWZOjY7T-dxQw==/109951173831863282.jpg", "popularity": 440, "onlineNumber": 1, "type": 1, "userInfo": {"liveRoomNo": 21623631, "userId": 351218439, "nickname": "Armin van Buuren", "avatarUrl": "http://p3.music.126.net/azOjMDuUPaj1hN4ZjS4nEw==/109951171948910186.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 1, "liveId": 134388747, "liveTitle": "Chillhop电台", "liveCoverUrl": "http://p3.music.126.net/KdsRE-fxakVXbaWi2AZ-9Q==/109951173366810246.jpg", "popularity": 34, "onlineNumber": 1, "type": 1, "userInfo": {"liveRoomNo": 217327486, "userId": 1728634721, "nickname": "Chillhop Music", "avatarUrl": "http://p4.music.126.net/vtmYMjdpdOCDNfCCvfUetA==/109951169698664040.jpg"}, "liveUrl": {"hlsPullUrl": "http://pullhls67a4fdc7.live.126.net/live/21772191d8f249d7993b3e95adea2602/playlist.m3u8", "httpPullUrl": "http://flv67a4fdc7.live.126.net/live/21772191d8f249d7993b3e95adea2602.flv?netease=flv67a4fdc7.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 1, "liveId": 134046414, "liveTitle": "一人评论一句", "liveCoverUrl": "http://p3.music.126.net/R_eggJlQZUgv5tXXRAP5hw==/109951168125145498.jpg", "popularity": 41, "onlineNumber": 1, "type": 51, "userInfo": {"liveRoomNo": 95878198, "userId": 250700726, "nickname": "崽崽", "avatarUrl": "http://p4.music.126.net/fn60XA2IE6sN906ejmxPHQ==/109951168060283670.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/c0a6ec3b81d74a50b9c8861ea0696d53/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/c0a6ec3b81d74a50b9c8861ea0696d53.flv?netease=pull0583d674.live.126.net"}}}], "labelBar": {"currentLabelId": 0, "labelList": [{"labelName": "热门", "labelId": 0, "totalCount": 0}]}, "topBanner": null, "hasMore": false, "offset": 20}, "success": true}';

/// The recorded voice list, page 1 (19 voice cards and one injected video card).
const String audioListP1Body =
    '{"code": 200, "msg": null, "data": {"itemList": [{"type": "1", "liveData": {"liveType": 1, "liveId": 134469447, "liveTitle": "全天公会赛求援", "liveCoverUrl": "http://p4.music.126.net/pyeqT3vxmwk9Q5xqW9eFPw==/109951172220210492.jpg", "popularity": 22104, "onlineNumber": 47, "type": 50, "userInfo": {"liveRoomNo": 495455091, "userId": 8060813546, "nickname": "EL-YOLO-聘诉看个签", "avatarUrl": "http://p3.music.126.net/WcijUvoBlKQQHHkC4z7HuQ==/109951172220735404.jpg"}, "liveUrl": null}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134601372, "liveTitle": "今天发誓拿下你", "liveCoverUrl": "http://p3.music.126.net/6FopOeorGG_pRN4ye8CbTA==/109951172551083886.jpg", "popularity": 8382, "onlineNumber": 14, "type": 6, "userInfo": {"liveRoomNo": 125684768, "userId": 1461100267, "nickname": "森屿", "avatarUrl": "http://p4.music.126.net/2xHjZpzq6uuO2eJ_GXD1xA==/109951173989551179.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/3ff3de40fc604927a5fa71e7a94a61d7/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/3ff3de40fc604927a5fa71e7a94a61d7.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134596484, "liveTitle": "今年也请继续见面吧～", "liveCoverUrl": "http://p3.music.126.net/_53N5Z8uNxdK-kCMywLfrw==/109951168698291557.jpg", "popularity": 2562, "onlineNumber": 16, "type": 6, "userInfo": {"liveRoomNo": 478667579, "userId": 7892610362, "nickname": "是一只小满-众筹18w过梯度", "avatarUrl": "http://p3.music.126.net/W4Q9ZcQDMfDEQXkGeL5OOw==/109951173436568521.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/81bc4696866340eeb69af51fa309f8a2/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/81bc4696866340eeb69af51fa309f8a2.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134600435, "liveTitle": "把我当成她吧", "liveCoverUrl": "http://p4.music.126.net/4jVwaWv6LO1ptI7Rhr-SMQ==/109951172706145278.jpg", "popularity": 1942, "onlineNumber": 8, "type": 6, "userInfo": {"liveRoomNo": 591080427, "userId": 12934072127, "nickname": "啾不甜", "avatarUrl": "http://p4.music.126.net/bejSJpgxho17Qe7rTcPBwA==/109951173934068931.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/7880969df9cf4b88a098f815923d7585/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/7880969df9cf4b88a098f815923d7585.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134599416, "liveTitle": "助力农村孩子实现梦想", "liveCoverUrl": "http://p3.music.126.net/GN9kB9veMW9ZzTuxt6vb0Q==/109951173590999979.jpg", "popularity": 2884, "onlineNumber": 7, "type": 6, "userInfo": {"liveRoomNo": 314647747, "userId": 3287735575, "nickname": "姩姩RovY", "avatarUrl": "http://p4.music.126.net/JYCZHaCxZULyM0GByHo_tA==/109951173816137098.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/6c0f019a75384f0e9e33161a79d8bfc4/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/6c0f019a75384f0e9e33161a79d8bfc4.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134598459, "liveTitle": "进来不许叫宝宝☔", "liveCoverUrl": "http://p4.music.126.net/kBBd2lFAX00A77oUA2jAbw==/109951173876745046.jpg", "popularity": 2372, "onlineNumber": 11, "type": 6, "userInfo": {"liveRoomNo": 432899621, "userId": 3975804468, "nickname": "坏貝_", "avatarUrl": "http://p4.music.126.net/cj54QkSVfU6obihQthZjuA==/109951173957327317.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/912a008fbb5149eaaeb8474ec93b1863/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/912a008fbb5149eaaeb8474ec93b1863.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134597445, "liveTitle": "在云村做主播是种什么体验", "liveCoverUrl": "http://p4.music.126.net/Kj45PXsr0x4inQ1ssaX6Lg==/109951171518095051.jpg", "popularity": 40, "onlineNumber": 1, "type": 6, "userInfo": {"liveRoomNo": 600050825, "userId": 13351158463, "nickname": "阿月啊_ayuea", "avatarUrl": "http://p3.music.126.net/T0bxvHLANMydf7ARj9mKvQ==/109951171458364799.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/b453cceba42148928c1205ce28b76417/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/b453cceba42148928c1205ce28b76417.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134606327, "liveTitle": "像水一样平静🧊", "liveCoverUrl": "http://p4.music.126.net/VUgAgqp41c8CPv5vph3gSw==/109951172416235947.jpg", "popularity": 493, "onlineNumber": 6, "type": 6, "userInfo": {"liveRoomNo": 24617315, "userId": 476791862, "nickname": "慵懒兔ya", "avatarUrl": "http://p4.music.126.net/gasXYvPq8XEhVfyv1KOupA==/109951172421208833.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/a1d106fd9c6e4f2e9d8e9d6fec82d596/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/a1d106fd9c6e4f2e9d8e9d6fec82d596.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134595753, "liveTitle": "一个默默无闻的…", "liveCoverUrl": "http://p4.music.126.net/Lt7VUzMY92H4ilhGiJKBjg==/109951173987853023.jpg", "popularity": 60, "onlineNumber": 2, "type": 6, "userInfo": {"liveRoomNo": 502841223, "userId": 1376139971, "nickname": "Saknsx", "avatarUrl": "http://p4.music.126.net/ARKfYXIsVBHZ29EC9S8SBw==/109951174001984734.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/896b19681d59472bafa86c8557b8d8bf/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/896b19681d59472bafa86c8557b8d8bf.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134610233, "liveTitle": "你的专属秘密树洞", "liveCoverUrl": "http://p4.music.126.net/Qq6pr5g8y1QVNiz8YDT6mw==/109951165323651127.jpg", "popularity": 56, "onlineNumber": 2, "type": 6, "userInfo": {"liveRoomNo": 264336243, "userId": 2007238542, "nickname": "苏丹", "avatarUrl": "http://p4.music.126.net/PMobC9LwsggqKkXHTK2rBw==/109951174003954654.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/6742519053174ca2b8c599e2f858d111/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/6742519053174ca2b8c599e2f858d111.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134600438, "liveTitle": "好久不见，中秋快乐", "liveCoverUrl": "http://p4.music.126.net/JYuPf1q28MHBAeohajHczw==/109951165939044854.jpg", "popularity": 201, "onlineNumber": 4, "type": 6, "userInfo": {"liveRoomNo": 213364881, "userId": 403158134, "nickname": "木头人", "avatarUrl": "http://p4.music.126.net/S0oNVlq_S20xNRQJsNfx-A==/109951173640626038.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/8efb545d7adb4a969d002cdfe3894c97/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/8efb545d7adb4a969d002cdfe3894c97.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134609307, "liveTitle": "安静的人 安静的直播间～", "liveCoverUrl": "http://p3.music.126.net/G47Qwky1H11CcgSb_xt8GQ==/109951173939521577.jpg", "popularity": 102, "onlineNumber": 2, "type": 6, "userInfo": {"liveRoomNo": 279358327, "userId": 2089949230, "nickname": "Y-安露许愿心动热气球", "avatarUrl": "http://p4.music.126.net/xSRkNKG5AEFii5r5gn90_A==/109951173876749687.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/2abf4272bc5f4a7984a037b6ba57c6cb/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/2abf4272bc5f4a7984a037b6ba57c6cb.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134599444, "liveTitle": "单曲循环的流行歌曲", "liveCoverUrl": "http://p3.music.126.net/U4LsFo_rmOsmxPfMxHuMFQ==/109951172929278745.jpg", "popularity": 162, "onlineNumber": 1, "type": 6, "userInfo": {"liveRoomNo": 229465367, "userId": 1923405325, "nickname": "我没那么帅别对我太崇敬_", "avatarUrl": "http://p3.music.126.net/LOtm4GA8d_vg6o3VezWyfg==/109951172312609996.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/536a44f386e346bcafcbf99df9d735e7/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/536a44f386e346bcafcbf99df9d735e7.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134609306, "liveTitle": "说话！遇到难回答的又不说话了", "liveCoverUrl": "http://p4.music.126.net/PT2_PdX8akhlQUdYKm0Z1A==/109951169892760620.jpg", "popularity": 302, "onlineNumber": 2, "type": 6, "userInfo": {"liveRoomNo": 229021175, "userId": 1687853544, "nickname": "施情画意.", "avatarUrl": "http://p4.music.126.net/I67EtD0bvqdaxNho2Xyi_w==/109951171297759515.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/791027c0cc494f6ab4d62e62e9ce3e08/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/791027c0cc494f6ab4d62e62e9ce3e08.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134604374, "liveTitle": "倘若我们还有话说", "liveCoverUrl": "http://p4.music.126.net/ZvqnCoErgQT27E_zuByWHA==/109951168892050667.jpg", "popularity": 100, "onlineNumber": 3, "type": 6, "userInfo": {"liveRoomNo": 372701909, "userId": 3921438516, "nickname": "胆Dan", "avatarUrl": "http://p3.music.126.net/vyWq2iMPvwg11GvVoEVXUQ==/109951169711751565.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/76d7758925e74d9fa49ccbe8a62ba9ce/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/76d7758925e74d9fa49ccbe8a62ba9ce.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134599440, "liveTitle": "纯素颜直播❤️", "liveCoverUrl": "http://p4.music.126.net/0xPzbKQCl-TUxpBrUl5sKg==/109951172552659401.jpg", "popularity": 1923, "onlineNumber": 9, "type": 6, "userInfo": {"liveRoomNo": 594274109, "userId": 13081003900, "nickname": "肉肉_Rosamond", "avatarUrl": "http://p4.music.126.net/cSlUWZbawBvHsOyEclGDwg==/109951173908918192.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/ba36d0b26a6e4a06a10df825f14435a6/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/ba36d0b26a6e4a06a10df825f14435a6.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134599439, "liveTitle": "花花世界太危险，只有这里才是温柔乡", "liveCoverUrl": "http://p4.music.126.net/8xFddLtX3GmgiAu6QcoZQg==/109951169236002937.jpg", "popularity": 75, "onlineNumber": 2, "type": 6, "userInfo": {"liveRoomNo": 442167192, "userId": 5216673353, "nickname": "憨憨", "avatarUrl": "http://p3.music.126.net/kI1LHRPJBtz_XcTzEWLw9g==/109951170430953516.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/28157987071a4efda9ba48766f225f39/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/28157987071a4efda9ba48766f225f39.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134600437, "liveTitle": "look一股清流", "liveCoverUrl": "http://p4.music.126.net/S-mdYOe-QnVfDqqhyF-ryA==/109951174008029560.jpg", "popularity": 177, "onlineNumber": 2, "type": 6, "userInfo": {"liveRoomNo": 651143864, "userId": 17724754660, "nickname": "vigor呀", "avatarUrl": "http://p3.music.126.net/PwPW3W-GEuLhPFR6y-TO0A==/109951174004746826.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/bd35c987cad64f429ccdad5c5a78fec5/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/bd35c987cad64f429ccdad5c5a78fec5.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134604372, "liveTitle": "做你倾吐心事的树洞", "liveCoverUrl": "http://p4.music.126.net/9Q5f3AZQD1pZkC3G-KbNaQ==/109951173953757386.jpg", "popularity": 301, "onlineNumber": 4, "type": 6, "userInfo": {"liveRoomNo": 459493851, "userId": 6415609372, "nickname": "林M雨", "avatarUrl": "http://p4.music.126.net/90vGBvoVSm2gCFbL8dhg_g==/109951166997491127.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/891f5f9eeaad45b2936d7185e90c928d/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/891f5f9eeaad45b2936d7185e90c928d.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134598467, "liveTitle": "点歌卡点免费，今天福利局", "liveCoverUrl": "http://p3.music.126.net/YIrZ7teUQ_RZbx9ROY-h4w==/109951173114679235.jpg", "popularity": 303, "onlineNumber": 2, "type": 6, "userInfo": {"liveRoomNo": 519989900, "userId": 8507159049, "nickname": "红妆", "avatarUrl": "http://p4.music.126.net/6rTc8bJI68igC57CzvcnJA==/109951173992362126.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/d945149449a44530ac2ac0ad9a0c79f0/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/d945149449a44530ac2ac0ad9a0c79f0.flv?netease=pull0583d674.live.126.net"}}}], "labelBar": {"currentLabelId": 0, "labelList": [{"labelName": "热门", "labelId": 0, "totalCount": 0}, {"labelName": "音乐", "labelId": 4001, "totalCount": 136}, {"labelName": "情感", "labelId": 5001, "totalCount": 193}, {"labelName": "二次元", "labelId": 43001, "totalCount": 31}, {"labelName": "红人馆", "labelId": 1121201, "totalCount": 5}]}, "topBanner": null, "hasMore": true}, "success": true}';

/// The recorded voice list, page 2 (20 voice cards).
const String audioListP2Body =
    '{"code": 200, "msg": null, "data": {"itemList": [{"type": "1", "liveData": {"liveType": 2, "liveId": 134598466, "liveTitle": "倾听树洞，聊一聊吧。", "liveCoverUrl": "http://p3.music.126.net/3VuP3we9POMPB1bNxSxsTw==/109951174001528356.jpg", "popularity": 376, "onlineNumber": 3, "type": 6, "userInfo": {"liveRoomNo": 181408025, "userId": 1751995745, "nickname": "南禾音", "avatarUrl": "http://p3.music.126.net/UEmtJmluvVipCFVFqfufzw==/109951174001440291.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/eb1b86b139d7455bbefbb9bd3037f688/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/eb1b86b139d7455bbefbb9bd3037f688.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134598464, "liveTitle": "我是真的爱上你", "liveCoverUrl": "http://p4.music.126.net/_Pgd7SWkYt0PWGREB7xO7g==/109951173714521111.jpg", "popularity": 824, "onlineNumber": 8, "type": 6, "userInfo": {"liveRoomNo": 325808387, "userId": 572793023, "nickname": "婆果西婆吆", "avatarUrl": "http://p4.music.126.net/qXh6yvfc1kqYyGCf5ZPEjQ==/109951173535081864.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/b9d2b60ca47c44298e6d6b5fd3349d01/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/b9d2b60ca47c44298e6d6b5fd3349d01.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134607297, "liveTitle": "倾听你，治愈你", "liveCoverUrl": "http://p4.music.126.net/re1lvkmBWXHlPo0MnXHrXA==/109951172548290916.jpg", "popularity": 1038, "onlineNumber": 5, "type": 6, "userInfo": {"liveRoomNo": 378046308, "userId": 3948652467, "nickname": "九荔_暖暖版", "avatarUrl": "http://p3.music.126.net/E2UCtqOBh_5_9_SUgs2YWw==/109951169789419056.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/252743570ca243258d14eba11e3f91c4/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/252743570ca243258d14eba11e3f91c4.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134609302, "liveTitle": "湖北第一纯情", "liveCoverUrl": "http://p3.music.126.net/4ZWl1-wxcaYAzq2vodFyCA==/109951172112163096.jpg", "popularity": 883, "onlineNumber": 7, "type": 6, "userInfo": {"liveRoomNo": 485752076, "userId": 7961640766, "nickname": "甜熙熙-急头巴老愁13W梯度", "avatarUrl": "http://p4.music.126.net/nKWB77nR1jYbDrVQVW4RlQ==/109951173980134897.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/3ffe87a426a24e50be0e9dbae38ae232/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/3ffe87a426a24e50be0e9dbae38ae232.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134595751, "liveTitle": "知心姐姐开播啦～", "liveCoverUrl": "http://p3.music.126.net/7MyJVNlUCLdhBlTX6DjKYA==/109951168690890168.jpg", "popularity": 444, "onlineNumber": 4, "type": 6, "userInfo": {"liveRoomNo": 379066633, "userId": 505712550, "nickname": "释子是柿子", "avatarUrl": "http://p3.music.126.net/WS9pqggStzUGtJpKUdG0rw==/109951169503578210.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/89ebec5e473649bd9a090e0e4b9d78b2/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/89ebec5e473649bd9a090e0e4b9d78b2.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134610232, "liveTitle": "说你想念我的呢喃", "liveCoverUrl": "http://p4.music.126.net/LD8YcK4mdUK0fKP7WMrAJg==/109951173969931459.jpg", "popularity": 630, "onlineNumber": 6, "type": 6, "userInfo": {"liveRoomNo": 453310516, "userId": 6364034185, "nickname": "麓小橘", "avatarUrl": "http://p3.music.126.net/Qp3AhgwucCKz4Uzd0KCaew==/109951173975066548.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/66a8548b12204c79acd7e4c3ec29ea45/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/66a8548b12204c79acd7e4c3ec29ea45.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134599432, "liveTitle": "只是对你温柔", "liveCoverUrl": "http://p4.music.126.net/aiflEdcFTFvDwvfiUjykXw==/109951168767254321.jpg", "popularity": 184, "onlineNumber": 3, "type": 6, "userInfo": {"liveRoomNo": 529808276, "userId": 8664625579, "nickname": "小馨欣---", "avatarUrl": "http://p3.music.126.net/vjMbS9QZ8EMrNyaTpItObQ==/109951169699235488.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/39fe8d0a66b6426b8996eb5bd7390f08/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/39fe8d0a66b6426b8996eb5bd7390f08.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134610969, "liveTitle": "自古逢秋悲寂寥", "liveCoverUrl": "http://p4.music.126.net/z-xhaXP7OY-sKw271O3QTQ==/109951172437760488.jpg", "popularity": 1228, "onlineNumber": 5, "type": 6, "userInfo": {"liveRoomNo": 237490849, "userId": 1544392167, "nickname": "匿名", "avatarUrl": "http://p3.music.126.net/WOw3ViSlgoJszSK8-9K_RQ==/109951174009822303.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/94d47f64b5c3460e88ceddc7f07e2aff/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/94d47f64b5c3460e88ceddc7f07e2aff.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134596485, "liveTitle": "你的痛苦我都添乱 生怕你解决", "liveCoverUrl": "http://p3.music.126.net/SFsf71KvmtAXt6TE4N5MXg==/109951174014972947.jpg", "popularity": 385, "onlineNumber": 4, "type": 6, "userInfo": {"liveRoomNo": 290046568, "userId": 1720521026, "nickname": "今晚台灯没电了", "avatarUrl": "http://p4.music.126.net/XHi3InlETbT1pdbP-lmAeQ==/109951171465694002.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/6a3636f3aeaa4325b362d9081817fe38/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/6a3636f3aeaa4325b362d9081817fe38.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134610230, "liveTitle": "我有酒你有故事吗", "liveCoverUrl": "http://p3.music.126.net/jjDKJYjjW6h-DxAkMqCdDw==/109951168543257349.jpg", "popularity": 37, "onlineNumber": 1, "type": 6, "userInfo": {"liveRoomNo": 241281048, "userId": 1802750812, "nickname": "小仙女999z", "avatarUrl": "http://p3.music.126.net/BXe-ksVBY3RsRlUqAUEFEQ==/109951167743442117.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/6b14bdc6ded645a98e0e8d36aeaf8004/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/6b14bdc6ded645a98e0e8d36aeaf8004.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134602356, "liveTitle": "一粒种子的旅行", "liveCoverUrl": "http://p3.music.126.net/QbvSj8o9MG8G3hDw0w2C6w==/109951172061186618.jpg", "popularity": 42, "onlineNumber": 1, "type": 6, "userInfo": {"liveRoomNo": 225810429, "userId": 1791327104, "nickname": "豆豆紫云", "avatarUrl": "http://p4.music.126.net/6H7S-N5y34lXcCXUepIU8w==/109951166521490225.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/ca3608cf38374e63b45d8ae63d0155ba/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/ca3608cf38374e63b45d8ae63d0155ba.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134602355, "liveTitle": "你在干什么呢～", "liveCoverUrl": "http://p4.music.126.net/9kc9oUgPc2CFdWzfU6KzEw==/109951173928466674.jpg", "popularity": 444, "onlineNumber": 7, "type": 6, "userInfo": {"liveRoomNo": 273362228, "userId": 2069153318, "nickname": "宁婉秋-祝10月1日生日快乐版", "avatarUrl": "http://p4.music.126.net/Hx41QacFXDYMCZdJ_306hQ==/109951173929378963.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/3043607b680d464987e21c79f33d08e4/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/3043607b680d464987e21c79f33d08e4.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134602353, "liveTitle": "你的专属秘密树洞", "liveCoverUrl": "http://p3.music.126.net/sf60oLHTrVr-IWdrH6eLNA==/109951173778469042.jpg", "popularity": 1274, "onlineNumber": 7, "type": 6, "userInfo": {"liveRoomNo": 210710324, "userId": 1680046314, "nickname": "第3位注销中", "avatarUrl": "http://p4.music.126.net/XoNLHcBGudvNHtUBPxf_wg==/109951174009636285.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/25277865fdcc4a4ab0471ca0bf780f54/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/25277865fdcc4a4ab0471ca0bf780f54.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134600431, "liveTitle": "开播挣猫粮拉~", "liveCoverUrl": "http://p3.music.126.net/Ja3DmthvFK8p7hO87WONCw==/109951169023340329.jpg", "popularity": 1583, "onlineNumber": 8, "type": 6, "userInfo": {"liveRoomNo": 11319946, "userId": 454961991, "nickname": "白白", "avatarUrl": "http://p4.music.126.net/AEhbELRc2_UwN36Z9dy8dw==/109951172852200683.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/0179125c1234475f80962c861f39787a/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/0179125c1234475f80962c861f39787a.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134606323, "liveTitle": "等待一个有缘人", "liveCoverUrl": "http://p4.music.126.net/ATxjD20W999TO2jfKZeCAQ==/109951173947976264.jpg", "popularity": 127, "onlineNumber": 2, "type": 6, "userInfo": {"liveRoomNo": 350667806, "userId": 3721069827, "nickname": "碧丽莉", "avatarUrl": "http://p4.music.126.net/pAeOpFcdBb8TjbXrnsKa9A==/109951169615395449.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/5cffb23f96654faa91f9153da37362b2/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/5cffb23f96654faa91f9153da37362b2.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134602351, "liveTitle": "贵州最后少女", "liveCoverUrl": "http://p4.music.126.net/fVye-CE-ng3g50A42grSpw==/109951171412948299.jpg", "popularity": 824, "onlineNumber": 5, "type": 6, "userInfo": {"liveRoomNo": 576717118, "userId": 12327145932, "nickname": "朝朝财", "avatarUrl": "http://p4.music.126.net/86wtO3Q_ufsy6EH2cParzw==/109951173851326359.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/0c8b34633fdb4fe9984f38601f045d76/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/0c8b34633fdb4fe9984f38601f045d76.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134599428, "liveTitle": "高 雅 女 主 播", "liveCoverUrl": "http://p3.music.126.net/O4-EKJv1oDgGI8wc7u6CNw==/109951174006426342.jpg", "popularity": 1815, "onlineNumber": 11, "type": 6, "userInfo": {"liveRoomNo": 207739688, "userId": 281387786, "nickname": "慢", "avatarUrl": "http://p3.music.126.net/IEgp4JetPyieX-SVxqgbWg==/109951173977669720.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/25d25f8b74414dbe877985a4f0f9676e/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/25d25f8b74414dbe877985a4f0f9676e.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134600429, "liveTitle": "点歌热评999+歌曲！", "liveCoverUrl": "http://p4.music.126.net/24OoyDr3NdCiHFlimj2Bvg==/109951174005464672.jpg", "popularity": 49, "onlineNumber": 3, "type": 6, "userInfo": {"liveRoomNo": 366497413, "userId": 1878314879, "nickname": "娴babyGirl", "avatarUrl": "http://p3.music.126.net/0NrRDNSl8PXtBOG6jWZFRQ==/109951173999202211.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/21d52ccf48634ed7af35353537639778/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/21d52ccf48634ed7af35353537639778.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134602349, "liveTitle": "极品破碎音～", "liveCoverUrl": "http://p4.music.126.net/zFIozsQbsBNmlY0kI1E9DQ==/109951172828649713.jpg", "popularity": 413, "onlineNumber": 6, "type": 6, "userInfo": {"liveRoomNo": 634849609, "userId": 17433649993, "nickname": "许诺_筹筹梯度", "avatarUrl": "http://p4.music.126.net/du81o9RxUT_vWMloPvWvSA==/109951173992390591.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/e78c308adfb745f59d282dd7fd6c44c3/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/e78c308adfb745f59d282dd7fd6c44c3.flv?netease=pull0583d674.live.126.net"}}}, {"type": "1", "liveData": {"liveType": 2, "liveId": 134601368, "liveTitle": "你的心事我倾听", "liveCoverUrl": "http://p4.music.126.net/MBzmEqGu8pGizaBzTAW_og==/109951173551090181.jpg", "popularity": 601, "onlineNumber": 4, "type": 6, "userInfo": {"liveRoomNo": 265119741, "userId": 292368970, "nickname": "还是硕硕呐-", "avatarUrl": "http://p3.music.126.net/LMaidrybLbMCghyx56GO1Q==/109951173923848419.jpg"}, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/4725949ae14348d9b868c2d6a81a3f59/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/4725949ae14348d9b868c2d6a81a3f59.flv?netease=pull0583d674.live.126.net"}}}], "labelBar": {"currentLabelId": 0, "labelList": [{"labelName": "热门", "labelId": 0, "totalCount": 0}, {"labelName": "音乐", "labelId": 4001, "totalCount": 135}, {"labelName": "情感", "labelId": 5001, "totalCount": 194}, {"labelName": "二次元", "labelId": 43001, "totalCount": 30}, {"labelName": "红人馆", "labelId": 1121201, "totalCount": 5}]}, "topBanner": null, "hasMore": true}, "success": true}';

/// The recorded video list, page 2: past its end (`itemList` null, `hasMore` false).
const String videoListP2Body =
    '{"code": 200, "msg": null, "message": null, "data": {"itemList": null, "labelBar": {"currentLabelId": 0, "labelList": [{"labelName": "热门", "labelId": 0, "totalCount": 0}]}, "topBanner": null, "hasMore": false, "offset": 20}, "success": true}';

/// The recorded room answer of the video room 21623631 (live, both streams).
const String roomVideoBody =
    '{"code": 200, "data": {"liveStatus": 1, "anonymousMode": false, "feeInfo": null, "anchor": {"liveRoomNo": "21623631", "userId": 351218439, "nickName": "Armin van Buuren", "avatarUrl": "http://p2.music.126.net/azOjMDuUPaj1hN4ZjS4nEw==/109951171948910186.jpg"}, "roomInfo": {"id": 134543183, "liveType": 1, "title": "ASOT电音电台直播中", "liveCoverUrl": "https://p1.music.126.net/y-H5ttUqsAWZOjY7T-dxQw==/109951173831863282.jpg", "liveStreamType": 1, "startTime": 1787733200612, "roomId": 462192286, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5.flv?netease=pull0583d674.live.126.net"}}}, "message": ""}';

/// The recorded room answer of the voice room 181408025 (live).
const String roomAudioBody =
    '{"code": 200, "data": {"liveStatus": 1, "anonymousMode": false, "feeInfo": null, "anchor": {"liveRoomNo": "181408025", "userId": 1751995745, "nickName": "南禾音", "avatarUrl": "http://p2.music.126.net/UEmtJmluvVipCFVFqfufzw==/109951174001440291.jpg"}, "roomInfo": {"id": 134598466, "liveType": 2, "title": "倾听树洞，聊一聊吧。", "liveCoverUrl": "https://p1.music.126.net/3VuP3we9POMPB1bNxSxsTw==/109951174001528356.jpg", "liveStreamType": 6, "startTime": 1790529120883, "roomId": 16272838887, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/eb1b86b139d7455bbefbb9bd3037f688/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/eb1b86b139d7455bbefbb9bd3037f688.flv?netease=pull0583d674.live.126.net"}}}, "message": ""}';

/// The recorded room answer for a room that does not exist (`code` 404).
const String roomNotFoundBody = '{"code": 404, "message": "直播间不存在", "debugInfo": null, "data": null, "failData": null}';

/// The recorded room answer of the app-only room 645235480 (live, stream type 50, no streams).
const String roomAppOnlyBody =
    '{"code": 200, "data": {"liveStatus": 1, "anonymousMode": false, "feeInfo": null, "anchor": {"liveRoomNo": "645235480", "userId": 17650321062, "nickName": "zy-晗辰男友-天使冠29厅战", "avatarUrl": "http://p2.music.126.net/YcoBFixxU6ofZDsyJJliNg==/109951173913490749.jpg"}, "roomInfo": {"id": 134529157, "liveType": 1, "title": "在云村做主播是种什么体验", "liveCoverUrl": "https://p2.music.126.net/jEmV4EAKaS9LODXrH2o6rg==/109951173440354652.jpg", "liveStreamType": 50, "startTime": 1787076274614, "roomId": 15148749147, "liveUrl": null}}, "message": ""}';

/// The recorded room answer of an ended room (liveStatus 0).
const String roomOfflineBody =
    '{"code": 200, "data": {"liveStatus": -1, "anonymousMode": false, "feeInfo": null, "anchor": {"liveRoomNo": "325808387", "userId": 572793023, "nickName": "婆果西婆吆", "avatarUrl": "http://p1.music.126.net/qXh6yvfc1kqYyGCf5ZPEjQ==/109951173535081864.jpg"}, "roomInfo": {"id": 134598464, "liveType": 2, "title": "我是真的爱上你", "liveCoverUrl": "https://p2.music.126.net/_Pgd7SWkYt0PWGREB7xO7g==/109951173714521111.jpg", "liveStreamType": 6, "startTime": 1790528802334, "roomId": 909690154, "liveUrl": {"hlsPullUrl": "http://pull0583d674.live.126.net/live/b9d2b60ca47c44298e6d6b5fd3349d01/playlist.m3u8", "httpPullUrl": "http://pull0583d674.live.126.net/live/b9d2b60ca47c44298e6d6b5fd3349d01.flv?netease=pull0583d674.live.126.net"}}}, "message": ""}';

/// The recorded form body of the video room's request: the `weapi`
/// envelope of `{liveRoomNo: "21623631"}`, byte for byte.
const String roomVideoRequestBody =
    'params=1Tj%2Brp0BPunszj2VG7qpfM1E6qoUixjO7CPI%2B6CKGQxt6zJT23WuolhlA7I%2Fno6V&encSecKey=35701388baf89fed412e11269b9c76625d095ecaf17f03fa018abe19ea2d38b949debf242ee39a71ca1f6cda71b1b86a45aa909ee27f7e78e267d34e732f0de948206c3340a788d0003372183e2f753c1f78b66ac23d134ac1fc9b993156520ea826b8aa89a962d4491b4b8d7e08738e1da9b07aa39bf4a7ef0b1c210728cd52';

/// The chat recording S05-live: the chat-server and socket.io answers, then the socket's frames, with their direction (and URL, for the two requests the recorder answered itself).
final List<({bool incoming, String? url, String text})> liveFrames = [
  (
    incoming: true,
    url: 'https://api.look.163.com/weapi/livestream/chat/address',
    text: '{"code":200,"msg":null,"message":null,"data":{"address":["chatwl01.yunxinfw.com:443","chatwl01-bgp.yunxinfw.com:443","chatwl02-bgp.yunxinfw.com:443","chatwl02.yunxinfw.com:443"]},"success":true}',
  ),
  (
    incoming: true,
    url: 'https://chatwl01.yunxinfw.com:443/socket.io/1/?t=1790770785968',
    text: '00000000-0000-4000-8000-000000000001:90:30:websocket,xhr-polling',
  ),
  (incoming: true, url: null, text: '1::'),
  (
    incoming: false,
    url: null,
    text: '3:::{"SID":13,"CID":2,"SER":1,"Q":[{"t":"byte","v":1},{"t":"Property","v":{"1":"3a6a3e48f6854dfa4e4464f3bdaec3b4","2":"nimanon_00000000000000000000000000000001","3":"00000000000000000000000000000002","5":9902460973,"8":0,"20":"匿名用户","21":" ","26":"00000000000000000000000000000003","38":1}},{"t":"Property","v":{"4":"Windows 10 64-bit","6":"47","8":1,"9":1,"13":"00000000000000000000000000000002","18":"3a6a3e48f6854dfa4e4464f3bdaec3b4","19":"nimanon_00000000000000000000000000000001","24":"Chrome 140.0.0.0","26":"00000000000000000000000000000003","1000":""}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: '3:::{"key":0,"ser":1,"code":200,"sid":13,"cid":2,"r":[{"16":"0","1":"9902460973","3":"online_liveChatRoom_110013407_564597113","100":"564597113","101":"26","102":"0","9":"1","12":"","14":"1738394848445","15":"1738394848461"},{"112":"1790770786778","2":"nimanon_00000000000000000000000000000001","3":"4","5":"匿名用户","6":" ","7":"","8":"1","9":"1","10":"1790770786778","107":"00000000000000000000000000000002","108":"00000000000000000000000000000003","111":"16"},{}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"5383c386f49e4fcc80f5da70be8aed5f","2":"100","3":"","20":"1790770787488","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"4744de8ffdad4b9f9105feab2ef74a77","2":"100","3":"","20":"1790770789243","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"10c26e48bb784704b7a10c83c35868e7","2":"0","3":"哇～ @观众4 出现了！一定是特别的缘分让我们相聚在这里","20":"1790770789087","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"8878bc5ff6cc45dead8734cd26b0f3b8","2":"0","3":"那我这端着的形象往哪放","20":"1790770791719","21":"1000000002","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"那我这端着的形象往哪放\",\"user\":{\"nickname\":\"观众2\",\"userId\":1000000002,\"liveLevel\":21,\"fanClubLevel\":11,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"7085657ea99343478f44f3ac16175103","2":"100","3":"","20":"1790770794543","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"a8102d74dde749efb0743466c83aaba8","2":"0","3":"哇~@观众5 来了！今天真开心，因为遇见了你~","20":"1790770794578","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"4b06d15baeb4494da200ad88cb5058d9","2":"100","3":"","20":"1790770799128","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"3f97540e6bda48f28e479b9ff1ff30b0","2":"0","3":"欢迎@观众6,总有些惊奇得际遇,比方说当我遇见你!","20":"1790770799163","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"00d09e8d68c54f7495acef40b02fcd31","2":"100","3":"","20":"1790770803877","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"2adc0baab4cd4fa798525e44d8b5460c","2":"0","3":"欢迎光临~@观众7,缘分让我们在这相聚,感谢有你~","20":"1790770803911","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"e783c684a06d43ceb0cc71c9abdf3f12","2":"0","3":"1","20":"1790770804169","21":"1000000002","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"1\",\"user\":{\"nickname\":\"观众2\",\"userId\":1000000002,\"liveLevel\":21,\"fanClubLevel\":11,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"d6d4ef4afbdc4917876fc9dff20c37ef","2":"100","3":"","20":"1790770804510","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"de031dda29944630829e4ca42d4801fe","2":"100","3":"","20":"1790770805046","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"04225e5bf7a04de287e7ce9e145170ad","2":"100","3":"","20":"1790770805117","21":"musiclive_server","22":"9902460973","4":"{\"type\":55000,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"5c2f38d674564da7956340aff428d37a","2":"0","3":"@观众8 欢迎进来！真是太幸运了，能在这里遇见你~","20":"1790770806133","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"01c2dc097d864d399a59fdcdeface4a5","2":"0","3":"666","20":"1790770809264","21":"1000000002","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"666\",\"user\":{\"nickname\":\"观众2\",\"userId\":1000000002,\"liveLevel\":21,\"fanClubLevel\":11,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"0308edc10b0143fd91764a533d5911a6","2":"100","3":"","20":"1790770822863","21":"musiclive_server","22":"9902460973","4":"{\"type\":303,\"id\":2}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"413c072abd7d46908ca52a8946f11097","2":"100","3":"","20":"1790770832273","21":"musiclive_server","22":"9902460973","4":"{\"type\":303,\"id\":2}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"20372df41cb649119c9a56fc79b19ad1","2":"0","3":"也是被抽象的世界驯服了","20":"1790770839238","21":"100000003","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"也是被抽象的世界驯服了\",\"user\":{\"nickname\":\"观众3\",\"userId\":100000003,\"liveLevel\":12,\"fanClubLevel\":8,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"dbd76c3546674d4797d881d1a506db55","2":"100","3":"","20":"1790770843643","21":"musiclive_server","22":"9902460973","4":"{\"type\":200067,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"575fa7740421415f8d38207c6f93cc83","2":"100","3":"","20":"1790770843712","21":"musiclive_server","22":"9902460973","4":"{\"type\":200067,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"4d4762380d2a44b59d94099b479517e6","2":"0","3":"就乐意搞点抽象","20":"1790770845036","21":"100000003","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"就乐意搞点抽象\",\"user\":{\"nickname\":\"观众3\",\"userId\":100000003,\"liveLevel\":12,\"fanClubLevel\":8,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"2d678482a5d5468a8062ac76d387afc3","2":"100","3":"","20":"1790770845939","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"145b9dfaa8e54ff2ab31acd92be42e7e","2":"100","3":"","20":"1790770846716","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"40015cf99eed437082913e90ed9eb616","2":"0","3":"@观众9 来了呀～ 今天的快乐因为你而加倍！欢迎","20":"1790770848238","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"7df78fab514f43259361a870ee365aa5","2":"100","3":"","20":"1790770850190","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"953bf9df4ec847ad934aaba9ae0b7da7","2":"100","3":"","20":"1790770850217","21":"musiclive_server","22":"9902460973","4":"{\"type\":55000,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"eb9fdd58a69a493c976986525eb496e4","2":"100","3":"","20":"1790770850712","21":"musiclive_server","22":"9902460973","4":"{\"type\":303,\"id\":2}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"8e1d9ec438914ca4a7bf881ca2f09637","2":"0","3":"欢迎光临~@观众10,缘分让我们在这相聚,感谢有你~","20":"1790770851253","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"6e86e5d6847441f1b00934d3f1142586","2":"100","3":"","20":"1790770852414","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"5b558ac54caf411390cb68e85853480c","2":"0","3":"欢迎 @观众11～ 茫茫人海，能在这里见到你，真好呀","20":"1790770854268","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"71e069fe8e314f2d8f206a3819bcf7c0","2":"100","3":"","20":"1790770856420","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"867e6e8fcfcc4151a6e46962bb913f28","2":"0","3":"欢迎@观众12！每一次的相遇都是上天安排，很高兴认识你~","20":"1790770856995","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"b55d5eb317d4482782de84e930520bb1","2":"100","3":"","20":"1790770869376","21":"musiclive_server","22":"9902460973","4":"{\"type\":200067,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"89aa65be56aa47489b5d3ce43fef9640","2":"100","3":"","20":"1790770877453","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"d5429ce671dc4ba2b48e98e6fa4611bc","2":"0","3":"欢迎 @观众13！缘分像风，把你吹到了我身边","20":"1790770879071","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"2b49de628e554ede946ca330197a9246","2":"100","3":"","20":"1790770881050","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"33d3dcbd2c0b4a85b69a7d8a0ea6aaba","2":"0","3":"哇～ @观众14 出现了！一定是特别的缘分让我们相聚在这里","20":"1790770882019","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"e39b2a49f10a41e0a41e3a168c221d4a","2":"0","3":"国庆快乐，阿離","20":"1790770896324","21":"1000000002","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"国庆快乐，阿離\",\"user\":{\"nickname\":\"观众2\",\"userId\":1000000002,\"liveLevel\":21,\"fanClubLevel\":11,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"1cc638feb0004c4a97a5fa03631a8d73","2":"100","3":"","20":"1790770898091","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"097942cc855b498eac255c378ca1f1fb","2":"0","3":"欢迎 @观众15！缘分像风，把你吹到了我身边","20":"1790770899719","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"d3f3b85c106e440dbdbff31b015932f7","2":"100","3":"","20":"1790770906727","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"e8d19fa5db3a4762b29fb2890893f00a","2":"100","3":"","20":"1790770906749","21":"musiclive_server","22":"9902460973","4":"{\"type\":55000,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"2badc0cd4f684aceb5dcee1a617f1ad6","2":"0","3":"@观众16 你好呀~欢迎来到我的直播间，这是缘分呢！","20":"1790770907035","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"64f4833500a94aaeae68f8e7a0b68f45","2":"100","3":"","20":"1790770907354","21":"musiclive_server","22":"9902460973","4":"{\"type\":200067,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"a374ed5bd2d4406d94e2b3856b1f12d5","2":"0","3":"学呗","20":"1790770909678","21":"100000003","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"学呗\",\"user\":{\"nickname\":\"观众3\",\"userId\":100000003,\"liveLevel\":12,\"fanClubLevel\":8,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"7ce9c7a09d934a9580002697168bed83","2":"0","3":"虽然唱起来要命","20":"1790770918618","21":"100000003","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"虽然唱起来要命\",\"user\":{\"nickname\":\"观众3\",\"userId\":100000003,\"liveLevel\":12,\"fanClubLevel\":8,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"ea4607740ae740cdb1454b357339cad7","2":"100","3":"","20":"1790770924203","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"a2faf9ce5dc94d08904db92efcb3aad8","2":"100","3":"","20":"1790770924268","21":"musiclive_server","22":"9902460973","4":"{\"type\":55000,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"eb75069ffb024285a9d665d67b3939e1","2":"0","3":"欢迎@观众17！每一次的相遇都是上天安排，很高兴认识你~","20":"1790770925792","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"a6c70ffae83045feb95d38a3ed8e18ca","2":"100","3":"","20":"1790770926409","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"942b5627971b4b0b9319a5eb85a560cb","2":"100","3":"","20":"1790770926889","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"3b73ae65f27b4a21aadca943a267156c","2":"0","3":"@观众18 欢迎你～ 遇见你是我的小幸运，一起开心玩耍吧","20":"1790770927806","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"bf8cfe41829a44a6b97aa2795bc53b95","2":"100","3":"","20":"1790770930815","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"f689482f24e343b785cee4fce85c6d15","2":"100","3":"","20":"1790770930839","21":"musiclive_server","22":"9902460973","4":"{\"type\":55000,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"a772e3812d404d28a587d29d173af190","2":"0","3":"@观众19 欢迎进来！真是太幸运了，能在这里遇见你~","20":"1790770930849","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"b8d39359b67749e18ef65ba6c4bf5c26","2":"100","3":"","20":"1790770936780","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"b4c3fa6565f84cae9e95142baf50e455","2":"0","3":"@观众20 来了呀！欢迎欢迎，希望能给你带来快乐~","20":"1790770936815","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"f84d1cea1c0943babf7e01f7d27b5204","2":"0","3":"明天就国庆了 不早了","20":"1790770942343","21":"100000003","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"明天就国庆了 不早了\",\"user\":{\"nickname\":\"观众3\",\"userId\":100000003,\"liveLevel\":12,\"fanClubLevel\":8,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"5681330b0b8d486ba039070e605893ac","2":"100","3":"","20":"1790770946625","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"a4f6464fb972450f9d4e398f64eb24b3","2":"0","3":"欢迎光临~@观众21,缘分让我们在这相聚,感谢有你~","20":"1790770948255","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"476648b041d146c28d239b182bbbcb3e","2":"0","3":"明天就国庆了 不早了","20":"1790770949866","21":"1000000002","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"明天就国庆了 不早了\",\"user\":{\"nickname\":\"观众2\",\"userId\":1000000002,\"liveLevel\":21,\"fanClubLevel\":11,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (incoming: false, url: null, text: '3:::{"SID":1,"CID":2,"SER":0}'),
  (incoming: true, url: null, text: '3:::{"key":0,"ser":0,"code":200,"sid":1,"cid":2,"r":[]}'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"ca35076f4802470da13f06d7434ce81f","2":"100","3":"","20":"1790770967946","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"13622aef3a254941ab20b026c7e9f109","2":"0","3":"欢迎 @观众22！每一次相遇都是礼物，谢谢你出现在这里","20":"1790770969567","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"7ad472124d0941c99d018505a1a47c4d","2":"100","3":"","20":"1790770977034","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"e3c76ed6d6614a34bef7bdd146f9e830","2":"0","3":"欢迎@观众23，世界那么大，我们却在这里相遇，真是不可思议~","20":"1790770977068","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"994dd0fbccbf4c54bfb42cb603f1732e","2":"0","3":"g调啊","20":"1790770979198","21":"100000003","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"g调啊\",\"user\":{\"nickname\":\"观众3\",\"userId\":100000003,\"liveLevel\":12,\"fanClubLevel\":8,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"c1b71965837448bf96946e26513c91f5","2":"100","3":"","20":"1790770979871","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"03126487a3894400816031ad128013db","2":"0","3":"欢迎 @观众16～ 美好的相遇从这一刻开始，很高兴认识你！","20":"1790770980404","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"12389a668e51402bb92a7a6527742f8e","2":"100","3":"","20":"1790770983898","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"74450598fdac448b8320c5738ab7c9f0","2":"0","3":"惊喜！@观众24 光临了~欢迎你，让我们一起度过美好时光~","20":"1790770983931","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"ab5373e09d33404ca852aef7208c7c5a","2":"100","3":"","20":"1790771005213","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"b5c8c285e9b6424a9e223f1a2c8a76b3","2":"100","3":"","20":"1790771005778","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"f7d8b88c507b4f05837a81374201b913","2":"0","3":"@观众25 你来啦！遇见你就是今天最大的惊喜","20":"1790771006787","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"02ce2d82bc814ebf9fc448133cd8f63b","2":"100","3":"","20":"1790771007524","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"02586477bf15493f92723aeb31cbeeeb","2":"0","3":"@观众26 欢迎光临～ 缘分让我们相遇，今天一定会很美好","20":"1790771009802","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"4af6891e973b4cd49cdd42b36cdeab1f","2":"100","3":"","20":"1790771011071","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"433118df6fb0462880a4b857d00afe1b","2":"0","3":"哇~@观众12 来了！今天真开心，因为遇见了你~","20":"1790771011803","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"75485ddb82f2473dafb13a4735998206","2":"100","3":"","20":"1790771016857","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"86fb731a463844079c2c31a48e8730ae","2":"0","3":"@观众18 欢迎你～ 遇见你是我的小幸运，一起开心玩耍吧","20":"1790771016892","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"db22e79e801d4393818add102d261805","2":"100","3":"","20":"1790771026275","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"bc6f284a33874a67b9edc6fa905d54c0","2":"0","3":"@观众27 欢迎你～ 遇见你是我的小幸运，一起开心玩耍吧","20":"1790771027828","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"b6a253ff2df94d95ad445a52034456bb","2":"100","3":"","20":"1790771036029","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"57d3825772e24ca2a84ff391d0c57214","2":"100","3":"","20":"1790771036050","21":"musiclive_server","22":"9902460973","4":"{\"type\":55000,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"644a3efb1af345db906447cfedaa9ced","2":"0","3":"@观众28 来啦！世界很大，幸好有你～ 欢迎欢迎","20":"1790771036063","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"a107537e850f466b8d8e837d6c9ece6d","2":"100","3":"","20":"1790771040322","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"6f10e6e8e1f34cac8bb11e3f7db60186","2":"100","3":"","20":"1790771040330","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"d9e8298ae5024fa08c20f53c6a6e65c8","2":"0","3":"叮咚～ @观众13 来了！欢迎欢迎，请随意坐，就像回家一样","20":"1790771040355","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"50b77e72fe184a29aab5cd55ab7787ff","2":"100","3":"","20":"1790771049436","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"7ecc6cb5a02040428938ae5ce7570310","2":"0","3":"欢迎@观众29！每一次的相遇都是上天安排，很高兴认识你~","20":"1790771051024","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"2d165e31a9f24bc59f86c0f91f484def","2":"100","3":"","20":"1790771061714","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"eb0b5435fd414284b3289e81d868bd7e","2":"0","3":"@观众16 欢迎你～ 遇见你是我的小幸运，一起开心玩耍吧","20":"1790771061749","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"8746188c340243ea93a1d6e19039ceb2","2":"0","3":"女生不算高","20":"1790771066038","21":"100000003","22":"9902460973","4":"{\"bizName\":\"iplay\",\"type\":0,\"content\":{\"text\":\"女生不算高\",\"user\":{\"nickname\":\"观众3\",\"userId\":100000003,\"liveLevel\":12,\"fanClubLevel\":8,\"fanClubName\":\"偏爱离\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"44135ea8c6a747d1bd8cb670f4a011a7","2":"100","3":"","20":"1790771073959","21":"musiclive_server","22":"9902460973","4":"{\"type\":303,\"id\":2}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"53666b7bc92047598c5acd42acc3692e","2":"100","3":"","20":"1790771074419","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"32e1162e62df48bd8133358184523a2b","2":"100","3":"","20":"1790771074746","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"198bd18b4ab143f08488c21510aa1d3f","2":"0","3":"@观众2 欢迎光临～ 缘分让我们相遇，今天一定会很美好","20":"1790771076575","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"60b27f0289e74a4dbbd7ab2ce8015d5c","2":"100","3":"","20":"1790771085579","21":"musiclive_server","22":"9902460973","4":"{\"type\":200067,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"218f57c7567c42948a8e9e74533c044c","2":"100","3":"","20":"1790771085719","21":"musiclive_server","22":"9902460973","4":"{\"type\":200067,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: true, url: null, text: '2::'),
  (incoming: false, url: null, text: '2::'),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"04407674dab247e5a2a349e1cd8e662a","2":"100","3":"","20":"1790771090681","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"f4510f7152ef41e1926922ab715be630","2":"0","3":"惊喜！@观众30 光临了~欢迎你，让我们一起度过美好时光~","20":"1790771090714","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"192edbb643ff40259ac36647fdbc5133","2":"100","3":"","20":"1790771090956","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"e60f29f8042d4c75a5c0787ab2ed466b","2":"100","3":"","20":"1790771092702","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"19ad2e4056e94647926040dfd5acbb9b","2":"0","3":"@观众31 来了呀！欢迎欢迎，希望能给你带来快乐~","20":"1790771092715","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"3f1d43d2d59c4acfbf7a266f9c4553f1","2":"100","3":"","20":"1790771100271","21":"musiclive_server","22":"9902460973","4":"{\"type\":200067,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"7510803b55bc4ad7bd4cf78ae579917a","2":"100","3":"","20":"1790771100346","21":"musiclive_server","22":"9902460973","4":"{\"type\":200067,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"4c41baa5fb7545f985bdab69fd4aa8fd","2":"100","3":"","20":"1790771101552","21":"musiclive_server","22":"9902460973","4":"{\"type\":114,\"id\":0}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"b62daf82d895411fb73e7512c3c7a26b","2":"0","3":"@观众32 你好呀～ 欢迎加入，希望这里能带给你快乐","20":"1790771103947","21":"1000000001","22":"9902460973","4":"{\"bizName\":\"iplay\",\"content\":{\"user\":{\"nickname\":\"观众1\",\"userId\":1000000001,\"liveLevel\":9,\"fanClubLevel\":1,\"fanClubName\":\"级偷懒\"}}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (incoming: false, url: null, text: '0::'),
];

/// The gift recording S06-gifts: four custom messages of type 102.
final List<({bool incoming, String? url, String text})> giftFrames = [
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"5ec5af7d94fc432bbe36dcb7eb6d43b7","2":"100","3":"","20":"1791531626046","21":"musiclive_server","22":"2491384966","4":"{\"type\":102,\"id\":0,\"content\":{\"user\":{\"nickName\":\"观众1\",\"userId\":7000000001,\"liveLevel\":38,\"fanClubLevel\":18,\"fanClubName\":\"口果汁\"},\"giftId\":14193526,\"giftName\":\"小麦穗\",\"number\":1,\"giftWorth\":1,\"giftIconUrl\":\"http://p1.music.126.net/rS6UvA8RznaFOobx26Uj8g==/109951173868759962.jpg\",\"receiver\":null}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"c84cc3cb303e4530945ac6ad917fca18","2":"100","3":"","20":"1791531851341","21":"musiclive_server","22":"2491384966","4":"{\"type\":102,\"id\":0,\"content\":{\"user\":{\"nickName\":\"观众2\",\"userId\":7000000002,\"liveLevel\":32,\"fanClubLevel\":8,\"fanClubName\":\"口果汁\"},\"giftId\":14202524,\"giftName\":\"时光相册\",\"number\":1,\"giftWorth\":1,\"giftIconUrl\":\"http://p1.music.126.net/F6veC4wFmEM389AzS2iX8Q==/109951173868769058.jpg\",\"receiver\":null}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"144f5f1eda1d41e488cf8c659b902341","2":"100","3":"","20":"1791531950058","21":"musiclive_server","22":"2491384966","4":"{\"type\":102,\"id\":0,\"content\":{\"user\":{\"nickName\":\"观众3\",\"userId\":7000000003,\"liveLevel\":4,\"fanClubLevel\":1,\"fanClubName\":\"口果汁\"},\"giftId\":14202524,\"giftName\":\"时光相册\",\"number\":1,\"giftWorth\":1,\"giftIconUrl\":\"http://p1.music.126.net/F6veC4wFmEM389AzS2iX8Q==/109951173868769058.jpg\",\"receiver\":null}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
  (
    incoming: true,
    url: null,
    text: r'3:::{"key":0,"ser":0,"code":200,"sid":4,"cid":10,"r":[0,{"body":[{"1":"c5ac01d9e3444362a7951e035b46859b","2":"100","3":"","20":"1791531571124","21":"musiclive_server","22":"435947765","4":"{\"type\":102,\"id\":0,\"content\":{\"user\":{\"nickName\":\"观众4\",\"userId\":7000000004,\"liveLevel\":65,\"fanClubLevel\":15,\"fanClubName\":\"倍爱嘉\"},\"giftId\":1047011,\"giftName\":\"旋转木马\",\"number\":1,\"giftWorth\":100,\"giftIconUrl\":\"http://p1.music.126.net/p2O-0SeKr3HK-UEydQ7G5g==/109951165024144012.jpg\",\"receiver\":null}}"}],"headerPacket":{"key":0,"sid":13,"cid":7}}]}',
  ),
];
